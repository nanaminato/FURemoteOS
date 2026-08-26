import 'package:flutter_test/flutter_test.dart';
import 'package:remoteos_client/core/auth/auth_service.dart';

void main() {
  test('session reports an authenticated state only with an access token', () {
    expect(
      const AuthSessionState(state: AuthState.authenticated).isAuthenticated,
      isFalse,
    );
    expect(
      const AuthSessionState(
        state: AuthState.authenticated,
        accessToken: 'access-token',
      ).isAuthenticated,
      isTrue,
    );
  });
}
