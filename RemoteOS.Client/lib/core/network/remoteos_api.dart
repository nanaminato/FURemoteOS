import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../auth/auth_service.dart';
import '../../features/auth/domain/auth_models.dart';

/// Shared authenticated REST transport for the RemoteOS v1 protocol.
///
/// Every URL is resolved from the active session instead of mutating a global
/// base address; this is important when the user switches remembered servers.
class RemoteOsApi {
  RemoteOsApi(this._auth);

  final AuthNotifier _auth;

  Uri endpoint(String path, [Map<String, String>? query]) {
    final server = _auth.current.serverUrl;
    if (server == null)
      throw const RemoteOsApiException(
          statusCode: 401, message: 'Not signed in.');
    final base = Uri.parse(server);
    return base
        .resolve(path.startsWith('/') ? path.substring(1) : path)
        .replace(queryParameters: query);
  }

  Future<dynamic> getJson(String path, {Map<String, String>? query}) =>
      _sendJson('GET', path, query: query);

  Future<dynamic> sendJson(String method, String path,
          {Object? body, Map<String, String>? query}) =>
      _sendJson(method, path, body: body, query: query);

  Future<dynamic> _sendJson(String method, String path,
      {Object? body, Map<String, String>? query}) async {
    final request = http.Request(method, endpoint(path, query))
      ..headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await http.Response.fromStream(
      await _auth
          .authenticatedClient()
          .send(request)
          .timeout(const Duration(seconds: 20)),
    );
    dynamic decoded;
    if (response.body.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        decoded = response.body;
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final map = decoded is Map ? decoded : const <String, dynamic>{};
      throw RemoteOsApiException(
        statusCode: response.statusCode,
        message: map['detail']?.toString() ??
            map['title']?.toString() ??
            'HTTP ${response.statusCode}',
        problemType: map['type']?.toString(),
      );
    }
    return decoded;
  }
}

final remoteOsApiProvider = Provider<RemoteOsApi>(
    (ref) => RemoteOsApi(ref.read(authProvider.notifier)));
