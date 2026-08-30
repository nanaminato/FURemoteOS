import '../../../core/apps/application_manifest.dart';

/// The authentication contract shared by RemoteOS desktop clients.
///
/// These types intentionally mirror `Shared/RemoteOS.Protocol/Identity` in the
/// source project. Keeping the wire contract here prevents UI code from
/// depending on untyped JSON maps.
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final DateTime refreshTokenExpiresAt;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final accessToken = json['accessToken'];
    final refreshToken = json['refreshToken'];
    final accessExpiresAt = json['accessTokenExpiresAt'];
    final refreshExpiresAt = json['refreshTokenExpiresAt'];
    if (accessToken is! String ||
        refreshToken is! String ||
        accessExpiresAt is! String ||
        refreshExpiresAt is! String) {
      throw const FormatException(
          'The server returned an invalid token payload.');
    }

    final parsedAccessExpiry = DateTime.tryParse(accessExpiresAt);
    final parsedRefreshExpiry = DateTime.tryParse(refreshExpiresAt);
    if (parsedAccessExpiry == null || parsedRefreshExpiry == null) {
      throw const FormatException(
          'The server returned invalid token expiration dates.');
    }

    return AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: parsedAccessExpiry.toLocal(),
      refreshTokenExpiresAt: parsedRefreshExpiry.toLocal(),
    );
  }
}

class LoginResult {
  const LoginResult({
    required this.tokens,
    required this.username,
    required this.workspaceId,
    required this.workspaceName,
    this.server,
  });

  final AuthTokens tokens;
  final String? username;
  final String? workspaceId;
  final String? workspaceName;
  final RemoteServerDescriptor? server;

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    final tokens = json['tokens'];
    if (tokens is! Map<String, dynamic>) {
      throw const FormatException(
          'The server returned an invalid login response.');
    }

    final user = json['user'];
    final workspace = json['workspace'];
    final server = json['server'];
    return LoginResult(
      tokens: AuthTokens.fromJson(tokens),
      username:
          user is Map<String, dynamic> ? user['username'] as String? : null,
      workspaceId:
          workspace is Map<String, dynamic> ? workspace['id'] as String? : null,
      workspaceName: workspace is Map<String, dynamic>
          ? workspace['name'] as String?
          : null,
      server: server is Map<String, dynamic>
          ? RemoteServerDescriptor.fromJson(server)
          : null,
    );
  }
}

class RemoteOsApiException implements Exception {
  const RemoteOsApiException({
    required this.statusCode,
    required this.message,
    this.problemType,
  });

  final int statusCode;
  final String message;
  final String? problemType;

  @override
  String toString() => 'RemoteOS API $statusCode: $message';
}
