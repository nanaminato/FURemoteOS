import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/remoteos_auth_api.dart';
import '../../features/auth/domain/auth_models.dart';
import '../apps/application_manifest.dart';

/// The lifecycle of an authenticated RemoteOS session.
enum AuthState { unauthenticated, authenticating, authenticated, error }

enum AuthEndReason { none, userInitiated, refreshTokenInvalid, networkError }

/// UI-facing snapshot of the RemoteOS authentication session.
///
/// Transport DTOs are deliberately kept in `features/auth`; this state only
/// exposes the data needed by routing and desktop features.
class AuthSessionState {
  const AuthSessionState({
    this.state = AuthState.unauthenticated,
    this.endReason = AuthEndReason.none,
    this.errorMessage,
    this.serverUrl,
    this.username,
    this.workspaceId,
    this.workspaceName,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.server,
  });

  final AuthState state;
  final AuthEndReason endReason;
  final String? errorMessage;
  final String? serverUrl;
  final String? username;
  final String? workspaceId;
  final String? workspaceName;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final RemoteServerDescriptor? server;

  bool get isAuthenticated =>
      state == AuthState.authenticated && accessToken != null;
  bool get isExpired => expiresAt == null || DateTime.now().isAfter(expiresAt!);
}

/// A locally remembered server/user pair.
class SavedLoginProfile {
  const SavedLoginProfile({
    required this.serverUrl,
    required this.username,
    required this.hasSavedPassword,
    required this.lastUsed,
  });

  final String serverUrl;
  final String username;

  /// The secret itself is held by the local credential file.
  /// SharedPreferences keeps only this non-sensitive UI hint.
  final bool hasSavedPassword;
  final DateTime lastUsed;

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'username': username,
        'hasSavedPassword': hasSavedPassword,
        'lastUsed': lastUsed.toIso8601String(),
      };

  factory SavedLoginProfile.fromJson(Map<String, dynamic> json) =>
      SavedLoginProfile(
        serverUrl: json['serverUrl'] as String,
        username: json['username'] as String,
        // Do not migrate the previous base64 value: it was not encryption.
        hasSavedPassword: json['hasSavedPassword'] as bool? ?? false,
        lastUsed: DateTime.parse(json['lastUsed'] as String),
      );
}

/// Session coordinator. It owns state transitions, while [RemoteOsAuthApi]
/// owns the `/api/v1/auth/*` wire protocol.
class AuthNotifier extends StateNotifier<AuthSessionState> {
  AuthNotifier({http.Client? httpClient, CredentialStore? credentialStore})
      : _httpClient = httpClient,
        _ownsHttpClient = httpClient == null,
        _credentialStore = credentialStore ?? FileCredentialStore(),
        super(const AuthSessionState());

  static const _prefsServerKey = 'auth.remembered.server';
  static const _prefsUsernameKey = 'auth.remembered.username';
  static const _prefsProfilesKey = 'auth.remembered.profiles';
  static const _clientVersion = '1.0.0-flutter';

  http.Client? _httpClient;
  bool _ownsHttpClient;
  final CredentialStore _credentialStore;

  http.Client get _client => _httpClient ??= http.Client();
  RemoteOsAuthApi get _api => RemoteOsAuthApi(_client);
  AuthSessionState get current => state;

  /// Allows test and application composition roots to supply one shared client.
  void setHttpClient(http.Client client) {
    if (_ownsHttpClient) _httpClient?.close();
    _httpClient = client;
    _ownsHttpClient = false;
  }

  Future<({String server, String username})> loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      server: prefs.getString(_prefsServerKey) ?? 'http://localhost:5090',
      username: prefs.getString(_prefsUsernameKey) ?? '',
    );
  }

  Future<List<SavedLoginProfile>> loadSavedProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final rawProfiles =
        prefs.getStringList(_prefsProfilesKey) ?? const <String>[];
    final profiles = <SavedLoginProfile>[];
    for (final rawProfile in rawProfiles) {
      try {
        profiles.add(SavedLoginProfile.fromJson(
            jsonDecode(rawProfile) as Map<String, dynamic>));
      } on FormatException {
        // Ignore a corrupt remembered profile rather than blocking sign-in.
      }
    }
    profiles.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    return profiles;
  }

  Future<String?> loadSavedPassword({
    required String serverUrl,
    required String username,
  }) =>
      _credentialStore.read(_passwordKey(serverUrl, username));

  bool isValidServerUrl(String value) => _parseServerUrl(value) != null;

  Future<bool> login({
    required String serverUrl,
    required String username,
    required String password,
    bool rememberServer = true,
    bool rememberPassword = false,
  }) async {
    final serverUri = _parseServerUrl(serverUrl);
    if (serverUri == null) {
      state = const AuthSessionState(
        state: AuthState.error,
        errorMessage:
            'The server address is invalid. Enter a complete HTTP or HTTPS address.',
      );
      return false;
    }

    state = AuthSessionState(
      state: AuthState.authenticating,
      serverUrl: serverUri.toString(),
      username: username,
    );

    try {
      final result = await _api.login(
        serverUrl: serverUri,
        username: username,
        password: password,
        deviceName: Platform.localHostname,
        clientVersion: _clientVersion,
      );
      state = AuthSessionState(
        state: AuthState.authenticated,
        serverUrl: serverUri.toString(),
        username: result.username ?? username,
        workspaceId: result.workspaceId,
        workspaceName: result.workspaceName,
        accessToken: result.tokens.accessToken,
        refreshToken: result.tokens.refreshToken,
        expiresAt: result.tokens.accessTokenExpiresAt,
        server: result.server,
      );
      // A successful remote authentication must not be invalidated merely
      // because optional local persistence (for example, an unavailable
      // desktop keychain) is unavailable.
      try {
        await _persistRemembered(serverUri.toString(), username, rememberServer,
            rememberPassword, password);
      } catch (_) {
        // The live session remains usable; the next sign-in can retry saving.
      }
      return true;
    } on RemoteOsApiException catch (error) {
      state = AuthSessionState(
        state: AuthState.error,
        serverUrl: serverUri.toString(),
        username: username,
        errorMessage: _messageForApiError(error),
      );
    } on TimeoutException {
      state = AuthSessionState(
        state: AuthState.error,
        serverUrl: serverUri.toString(),
        username: username,
        errorMessage: 'login.error.timeout'.tr(),
      );
    } on http.ClientException {
      state = AuthSessionState(
        state: AuthState.error,
        serverUrl: serverUri.toString(),
        username: username,
        errorMessage: 'login.error.connection_refused'.tr(),
      );
    } on FormatException {
      state = AuthSessionState(
        state: AuthState.error,
        serverUrl: serverUri.toString(),
        username: username,
        errorMessage: 'The server returned an invalid authentication response.',
      );
    } catch (error) {
      state = AuthSessionState(
        state: AuthState.error,
        serverUrl: serverUri.toString(),
        username: username,
        errorMessage:
            '${'login.error.unable_to_connect'.tr()}${error.toString().split('\n').first}',
      );
    }
    return false;
  }

  Future<bool> refreshToken() async {
    final current = state;
    final serverUri =
        current.serverUrl == null ? null : _parseServerUrl(current.serverUrl!);
    if (current.refreshToken == null || serverUri == null) return false;

    try {
      final tokens = await _api.refresh(
          serverUrl: serverUri, refreshToken: current.refreshToken!);
      state = AuthSessionState(
        state: AuthState.authenticated,
        serverUrl: current.serverUrl,
        username: current.username,
        workspaceId: current.workspaceId,
        workspaceName: current.workspaceName,
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        expiresAt: tokens.accessTokenExpiresAt,
        server: current.server,
      );
      return true;
    } on RemoteOsApiException catch (error) {
      if (error.statusCode == 401) {
        state = const AuthSessionState(
            endReason: AuthEndReason.refreshTokenInvalid);
      }
      return false;
    } catch (_) {
      // A transient failure must not discard a still-valid local session.
      return false;
    }
  }

  Future<void> logout() async {
    final current = state;
    final serverUri =
        current.serverUrl == null ? null : _parseServerUrl(current.serverUrl!);
    try {
      if (serverUri != null && current.accessToken != null) {
        await _api.logout(
          serverUrl: serverUri,
          accessToken: current.accessToken!,
          refreshToken: current.refreshToken,
        );
      }
    } finally {
      state = const AuthSessionState(endReason: AuthEndReason.userInitiated);
    }
  }

  Future<void> _persistRemembered(
    String serverUrl,
    String username,
    bool rememberServer,
    bool rememberPassword,
    String password,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (!rememberServer) {
      await prefs.remove(_prefsServerKey);
      await prefs.remove(_prefsUsernameKey);
      await _credentialStore.delete(_passwordKey(serverUrl, username));
      return;
    }

    await prefs.setString(_prefsServerKey, serverUrl);
    await prefs.setString(_prefsUsernameKey, username);
    final passwordKey = _passwordKey(serverUrl, username);
    var passwordSaved = false;
    if (rememberPassword) {
      try {
        await _credentialStore.write(passwordKey, password);
        passwordSaved = true;
      } catch (_) {
        // Preserve the login without falsely advertising that a password was
        // saved when the platform keychain rejects the request.
      }
    } else {
      try {
        await _credentialStore.delete(passwordKey);
      } catch (_) {
        // A stale optional credential must not affect the active session.
      }
    }
    final profiles = await loadSavedProfiles();
    final updatedProfiles = <SavedLoginProfile>[
      SavedLoginProfile(
        serverUrl: serverUrl,
        username: username,
        hasSavedPassword: passwordSaved,
        lastUsed: DateTime.now(),
      ),
      ...profiles.where((profile) =>
          profile.serverUrl != serverUrl || profile.username != username),
    ].take(10).toList();
    await prefs.setStringList(
      _prefsProfilesKey,
      updatedProfiles.map((profile) => jsonEncode(profile.toJson())).toList(),
    );
  }

  static Uri? _parseServerUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.isAbsolute ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return uri.replace(query: null, fragment: null);
  }

  static String _passwordKey(String serverUrl, String username) =>
      'remoteos.auth.password.v1.' +
      base64UrlEncode(utf8.encode('$serverUrl\u0000$username'));

  static String _messageForApiError(RemoteOsApiException error) {
    if (error.statusCode == 401) {
      return 'Invalid credentials. Please try again.';
    }
    if (error.statusCode == 404) {
      return 'The server does not expose the RemoteOS v1 authentication API. Check the server address and version.';
    }
    return error.message;
  }

  @override
  void dispose() {
    if (_ownsHttpClient) {
      _httpClient?.close();
    }
    super.dispose();
  }

  AuthenticatedHttpClient authenticatedClient() =>
      AuthenticatedHttpClient(this, _client);
}

/// Small seam around credential persistence so authentication can be tested
/// without touching the file system. Passwords must never be stored in
/// preferences.
abstract interface class CredentialStore {
  const CredentialStore();

  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// File-backed credential store. Secrets are kept as JSON in the user's
/// application-support directory instead of a platform keychain, avoiding the
/// native ATL dependency of `flutter_secure_storage` on Windows.
class FileCredentialStore implements CredentialStore {
  FileCredentialStore();

  static const _fileName = 'remoteos_credentials.json';
  final Map<String, String> _entries = <String, String>{};
  bool _loaded = false;
  Future<void>? _io;

  /// Serializes mutations so concurrent writes cannot interleave.
  Future<T> _synchronized<T>(Future<T> Function() action) {
    final previous = _io;
    final run = previous == null ? action() : previous.then((_) => action());
    _io = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  Future<void> _load() async {
    if (_loaded) return;
    final file = await _file();
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((key, value) {
            if (value is String) _entries[key] = value;
          });
        }
      } on FormatException {
        // Treat a corrupt file as empty rather than blocking sign-in.
      }
    }
    _loaded = true;
  }

  Future<void> _flush() async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(_entries));
  }

  @override
  Future<String?> read(String key) => _synchronized(() async {
        await _load();
        return _entries[key];
      });

  @override
  Future<void> write(String key, String value) => _synchronized(() async {
        await _load();
        _entries[key] = value;
        await _flush();
      });

  @override
  Future<void> delete(String key) => _synchronized(() async {
        await _load();
        if (_entries.remove(key) != null) await _flush();
      });
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthSessionState>(
  (ref) => AuthNotifier(),
);

final isAuthenticatedProvider = Provider<bool>(
  (ref) => ref.watch(authProvider.select((state) => state.isAuthenticated)),
);

/// Adds bearer authentication and retries once with refreshed credentials.
class AuthenticatedHttpClient extends http.BaseClient {
  AuthenticatedHttpClient(this.auth, this._inner);

  final AuthNotifier auth;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = auth.current.accessToken;
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.headers.putIfAbsent('Accept-Language', () => 'en-US');
    final response = await _inner.send(request);
    if (response.statusCode != 401 ||
        auth.current.refreshToken == null ||
        !await auth.refreshToken()) {
      return response;
    }

    final retry = await _cloneRequest(request);
    retry.headers['Authorization'] = 'Bearer ${auth.current.accessToken}';
    return _inner.send(retry);
  }

  static Future<http.BaseRequest> _cloneRequest(
      http.BaseRequest original) async {
    final request = http.Request(original.method, original.url)
      ..headers.addAll(original.headers)
      ..persistentConnection = original.persistentConnection
      ..followRedirects = original.followRedirects
      ..maxRedirects = original.maxRedirects;
    if (original is http.Request) request.bodyBytes = original.bodyBytes;
    return request;
  }
}
