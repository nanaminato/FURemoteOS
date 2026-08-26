import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;

import '../domain/auth_models.dart';

/// HTTP adapter for the RemoteOS authentication endpoints.
///
/// The paths and JSON fields match `Shared/RemoteOS.Protocol`. Do not add a
/// `BaseAddress` here: every call receives a server URL so multiple remembered
/// servers cannot leak state into one another.
class RemoteOsAuthApi {
  RemoteOsAuthApi(this._client);

  static const _loginPath = 'api/v1/auth/login';
  static const _refreshPath = 'api/v1/auth/refresh';
  static const _logoutPath = 'api/v1/auth/logout';

  final http.Client _client;

  Future<LoginResult> login({
    required Uri serverUrl,
    required String username,
    required String password,
    required String deviceName,
    required String clientVersion,
  }) async {
    final response = await _client
        .post(
          _endpoint(serverUrl, _loginPath),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'username': username,
            'password': password,
            'clientPlatform': Platform.isWindows ? 'windows' : 'linux',
            'deviceName': deviceName,
            'clientVersion': clientVersion,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = _decode(response);
    _ensureSuccess(response.statusCode, body);
    return LoginResult.fromJson(body);
  }

  Future<AuthTokens> refresh({
    required Uri serverUrl,
    required String refreshToken,
  }) async {
    final response = await _client
        .post(
          _endpoint(serverUrl, _refreshPath),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'refreshToken': refreshToken}),
        )
        .timeout(const Duration(seconds: 15));
    final body = _decode(response);
    _ensureSuccess(response.statusCode, body);
    final tokens = body['tokens'];
    if (tokens is! Map<String, dynamic>) {
      throw const FormatException(
          'The server returned an invalid refresh response.');
    }
    return AuthTokens.fromJson(tokens);
  }

  Future<void> logout({
    required Uri serverUrl,
    required String accessToken,
    required String? refreshToken,
  }) async {
    final response = await _client
        .post(
          _endpoint(serverUrl, _logoutPath),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({'refreshToken': refreshToken}),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _ensureSuccess(response.statusCode, _decode(response));
    }
  }

  static Uri _endpoint(Uri serverUrl, String path) => serverUrl.resolve(path);

  static Map<String, dynamic> _decode(http.Response response) {
    if (response.body.trim().isEmpty) return const {};
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
          'The server returned an invalid JSON response.');
    }
    return decoded;
  }

  static void _ensureSuccess(int statusCode, Map<String, dynamic> body) {
    if (statusCode >= 200 && statusCode < 300) return;
    throw RemoteOsApiException(
      statusCode: statusCode,
      message: body['detail'] as String? ??
          body['title'] as String? ??
          'HTTP $statusCode',
      problemType: body['type'] as String?,
    );
  }
}
