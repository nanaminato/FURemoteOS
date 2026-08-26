import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Authentication session state.
enum AuthState { unauthenticated, authenticating, authenticated, error }

/// End reason for auth transitions.
enum AuthEndReason {
  none,
  userInitiated,
  refreshTokenInvalid,
  networkError,
}

class AuthSessionState {
  final AuthState state;
  final AuthEndReason endReason;
  final String? errorMessage;
  final String? serverUrl;
  final String? username;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  const AuthSessionState({
    this.state = AuthState.unauthenticated,
    this.endReason = AuthEndReason.none,
    this.errorMessage,
    this.serverUrl,
    this.username,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  bool get isAuthenticated =>
      state == AuthState.authenticated && accessToken != null;

  bool get isExpired {
    if (expiresAt == null) return true;
    return DateTime.now().isAfter(expiresAt!);
  }

  AuthSessionState copyWith({
    AuthState? state,
    AuthEndReason? endReason,
    String? errorMessage,
    String? serverUrl,
    String? username,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) =>
      AuthSessionState(
        state: state ?? this.state,
        endReason: endReason ?? this.endReason,
        errorMessage: errorMessage ?? this.errorMessage,
        serverUrl: serverUrl ?? this.serverUrl,
        username: username ?? this.username,
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        expiresAt: expiresAt ?? this.expiresAt,
      );

  AuthSessionState clearTokens() => AuthSessionState(
        state: AuthState.unauthenticated,
        endReason: endReason,
        errorMessage: errorMessage,
        serverUrl: serverUrl,
        username: username,
      );
}

/// Remembered login profile for quick reconnect.
class SavedLoginProfile {
  final String serverUrl;
  final String username;
  final String? encryptedPassword;
  final DateTime lastUsed;

  const SavedLoginProfile({
    required this.serverUrl,
    required this.username,
    this.encryptedPassword,
    required this.lastUsed,
  });

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'username': username,
        'encryptedPassword': encryptedPassword,
        'lastUsed': lastUsed.toIso8601String(),
      };

  factory SavedLoginProfile.fromJson(Map<String, dynamic> json) =>
      SavedLoginProfile(
        serverUrl: json['serverUrl'] as String,
        username: json['username'] as String,
        encryptedPassword: json['encryptedPassword'] as String?,
        lastUsed: DateTime.parse(json['lastUsed'] as String),
      );
}

class AuthNotifier extends StateNotifier<AuthSessionState> {
  AuthNotifier() : super(const AuthSessionState());

  static const _prefsServerKey = 'auth.remembered.server';
  static const _prefsUsernameKey = 'auth.remembered.username';
  static const _prefsProfilesKey = 'auth.remembered.profiles';

  http.Client? _httpClient;

  /// Set a custom HTTP client (for testing or DI).
  void setHttpClient(http.Client client) => _httpClient = client;

  http.Client get _client => _httpClient ?? http.Client();

  /// Load remembered server/username from local storage.
  Future<({String server, String username})> loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      server: prefs.getString(_prefsServerKey) ?? 'http://localhost:5090',
      username: prefs.getString(_prefsUsernameKey) ?? '',
    );
  }

  /// Load all saved login profiles (without passwords unless secure storage available).
  Future<List<SavedLoginProfile>> loadSavedProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsProfilesKey);
    if (raw == null) return const [];
    final result = <SavedLoginProfile>[];
    for (final item in raw) {
      try {
        result.add(SavedLoginProfile.fromJson(jsonDecode(item) as Map<String, dynamic>));
      } catch (_) {}
    }
    result.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    return result;
  }

  /// Validate server URL format.
  bool isValidServerUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }

  /// Attempt to login.
  Future<bool> login({
    required String serverUrl,
    required String username,
    required String password,
    bool rememberServer = true,
    bool rememberPassword = false,
  }) async {
    if (!isValidServerUrl(serverUrl)) {
      state = state.copyWith(
        state: AuthState.error,
        errorMessage: 'login.error.invalid_server'.tr(),
      );
      return false;
    }

    state = state.copyWith(
      state: AuthState.authenticating,
      serverUrl: serverUrl,
      username: username,
      errorMessage: null,
    );

    try {
      final uri = Uri.parse('$serverUrl/api/auth/login');
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'deviceName': 'RemoteOS Flutter Client',
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final accessToken = body['accessToken'] as String?;
        final refreshToken = body['refreshToken'] as String?;
        final expiresIn = body['expiresIn'] as int? ?? 3600;

        state = state.copyWith(
          state: AuthState.authenticated,
          endReason: AuthEndReason.none,
          accessToken: accessToken,
          refreshToken: refreshToken,
          expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
          errorMessage: null,
        );

        await _persistRemembered(serverUrl, username, rememberServer, rememberPassword, password);
        return true;
      } else if (response.statusCode == 401) {
        state = state.copyWith(
          state: AuthState.error,
          errorMessage: 'Invalid credentials. Please try again.',
        );
      } else {
        state = state.copyWith(
          state: AuthState.error,
          errorMessage: '${'login.error.unable_to_connect'.tr()} HTTP ${response.statusCode}',
        );
      }
    } on FormatException {
      state = state.copyWith(
        state: AuthState.error,
        errorMessage: 'login.error.invalid_server'.tr(),
      );
    } on StateError catch (_) {
      state = state.copyWith(
        state: AuthState.error,
        errorMessage: 'login.error.connection_refused'.tr(),
      );
    } catch (e) {
      state = state.copyWith(
        state: AuthState.error,
        errorMessage: '${'login.error.unable_to_connect'.tr()} ${e.toString().split('\n').first}',
      );
    }
    return false;
  }

  Future<void> _persistRemembered(
    String serverUrl,
    String username,
    bool rememberServer,
    bool rememberPassword,
    String password,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (rememberServer) {
      await prefs.setString(_prefsServerKey, serverUrl);
      await prefs.setString(_prefsUsernameKey, username);
    } else {
      await prefs.remove(_prefsServerKey);
      await prefs.remove(_prefsUsernameKey);
    }

    final profiles = await loadSavedProfiles();
    final updated = <SavedLoginProfile>[
      SavedLoginProfile(
        serverUrl: serverUrl,
        username: username,
        encryptedPassword: rememberPassword ? _obfuscate(password) : null,
        lastUsed: DateTime.now(),
      ),
      ...profiles.where((p) => !(p.serverUrl == serverUrl && p.username == username)),
    ].take(10).toList();

    await prefs.setStringList(
      _prefsProfilesKey,
      updated.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  /// Simple, intentionally non-secure obfuscation for demo purposes.
  /// In production, use platform secure storage (flutter_secure_storage).
  static String _obfuscate(String input) =>
      base64.encode(utf8.encode(input));

  static String _deobfuscate(String encoded) {
    try {
      return utf8.decode(base64.decode(encoded));
    } catch (_) {
      return '';
    }
  }

  /// Attempt to refresh the access token.
  Future<bool> refreshToken() async {
    if (state.refreshToken == null || state.serverUrl == null) return false;
    try {
      final uri = Uri.parse('${state.serverUrl}/api/auth/refresh');
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': state.refreshToken}),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        state = state.copyWith(
          state: AuthState.authenticated,
          accessToken: body['accessToken'] as String?,
          refreshToken: body['refreshToken'] as String?,
          expiresAt: DateTime.now().add(Duration(seconds: body['expiresIn'] as int? ?? 3600)),
        );
        return true;
      }
    } catch (_) {}
    state = state.copyWith(
      state: AuthState.unauthenticated,
      endReason: AuthEndReason.refreshTokenInvalid,
    );
    return false;
  }

  /// Logout.
  Future<void> logout() async {
    state = state.clearTokens().copyWith(
          state: AuthState.unauthenticated,
          endReason: AuthEndReason.userInitiated,
        );
  }

  /// Get an authenticated HTTP client.
  AuthenticatedHttpClient authenticatedClient() =>
      AuthenticatedHttpClient(this, _client);
}

/// Provider for AuthNotifier.
final authProvider = StateNotifierProvider<AuthNotifier, AuthSessionState>(
  (ref) => AuthNotifier(),
);

/// Convenience: watch only auth status boolean.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider.select((s) => s.isAuthenticated));
});

/// An HTTP client that attaches the bearer token and refreshes on 401.
class AuthenticatedHttpClient extends http.BaseClient {
  final AuthNotifier auth;
  final http.Client _inner;

  AuthenticatedHttpClient(this.auth, this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    String? token = auth.state.accessToken;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Accept-Language'] = 'en-US';
    var response = await _inner.send(request);
    if (response.statusCode == 401 && auth.state.refreshToken != null) {
      final refreshed = await auth.refreshToken();
      if (refreshed) {
        final cloned = await _cloneRequest(request);
        cloned.headers['Authorization'] = 'Bearer ${auth.state.accessToken}';
        response = await _inner.send(cloned);
      }
    }
    return response;
  }

  static Future<http.BaseRequest> _cloneRequest(http.BaseRequest original) async {
    final request = http.Request(original.method, original.url);
    request.headers.addAll(original.headers);
    request.persistentConnection = original.persistentConnection;
    request.followRedirects = original.followRedirects;
    request.maxRedirects = original.maxRedirects;
    if (original is http.Request) {
      request.bodyBytes = original.bodyBytes;
    }
    return request;
  }
}
