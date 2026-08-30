import 'dart:io';
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


  /// Whether the current session is authenticated against a server.
  ///
  /// Mirrors the null-check of `_files` in Avalonia NotepadViewModel
  /// that gates open/save attempts before calling the remote service.
  bool get isConnected => _auth.current.isAuthenticated;
  Uri endpoint(String path, [Map<String, String>? query]) {
    final server = _auth.current.serverUrl;
    if (server == null) {
      throw const RemoteOsApiException(
          statusCode: 401, message: 'Not signed in.');
    }
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

  /// Sends a binary GET while retaining the current authenticated session.
  /// Callers must consume the response stream before issuing another transfer.
  Future<http.StreamedResponse> getStream(String path,
      {Map<String, String>? query}) async {
    final request = http.Request('GET', endpoint(path, query))
      ..headers['Accept'] = 'application/octet-stream';
    final response = await _auth
        .authenticatedClient()
        .send(request)
        .timeout(const Duration(seconds: 60));
    await _throwForStreamError(response);
    return response;
  }

  /// Sends raw bytes via [method] (typically PUT) for binary file content
  /// uploads, mirroring the server's `MapPut(FileApiRoutes.Content)` body
  /// stream contract. Distinct from [sendJson] because file content must not
  /// be JSON-encoded and may include arbitrary byte sequences.
  Future<void> sendBytes(String method, String path,
      {required List<int> bytes, Map<String, String>? query}) async {
    final request = http.Request(method, endpoint(path, query))
      ..headers['Accept'] = 'application/json'
      ..headers['Content-Type'] = 'application/octet-stream'
      ..bodyBytes = bytes;
    final response = await http.Response.fromStream(
      await _auth
          .authenticatedClient()
          .send(request)
          .timeout(const Duration(seconds: 60)),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      dynamic decoded;
      try {
        decoded =
            response.body.trim().isEmpty ? null : jsonDecode(response.body);
      } on FormatException {
        decoded = null;
      }
      final map = decoded is Map ? decoded : const <String, dynamic>{};
      throw RemoteOsApiException(
        statusCode: response.statusCode,
        message: map['detail']?.toString() ??
            map['title']?.toString() ??
            'HTTP ${response.statusCode}',
        problemType: map['type']?.toString(),
      );
    }
  }

  /// Posts a single local file as multipart/form-data. This is deliberately
  /// separate from [sendJson] because the Explorer upload endpoint requires a
  /// streamed file part rather than a JSON payload.
  Future<dynamic> sendFile(String path,
      {required File file, Map<String, String>? query}) async {
    final request = http.MultipartRequest('POST', endpoint(path, query))
      ..headers['Accept'] = 'application/json';
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await _auth
        .authenticatedClient()
        .send(request)
        .timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);
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
        message: map['message']?.toString() ??
            map['detail']?.toString() ??
            map['title']?.toString() ??
            'HTTP ${response.statusCode}',
        problemType: map['type']?.toString(),
      );
    }
    return decoded;
  }

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
        message: map['message']?.toString() ??
            map['detail']?.toString() ??
            map['title']?.toString() ??
            'HTTP ${response.statusCode}',
        problemType: map['type']?.toString(),
      );
    }
    return decoded;
  }

  Future<void> _throwForStreamError(http.StreamedResponse response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final text = await response.stream.bytesToString();
    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      decoded = null;
    }
    final map = decoded is Map ? decoded : const <String, dynamic>{};
    throw RemoteOsApiException(
      statusCode: response.statusCode,
      message: map['message']?.toString() ??
          map['detail']?.toString() ??
          map['title']?.toString() ??
          'HTTP ${response.statusCode}',
      problemType: map['type']?.toString(),
    );
  }
}

final remoteOsApiProvider = Provider<RemoteOsApi>(
    (ref) => RemoteOsApi(ref.read(authProvider.notifier)));
