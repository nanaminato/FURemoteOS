import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:remoteos_client/core/auth/auth_service.dart';
import 'package:remoteos_client/core/network/remoteos_api.dart';
import 'package:remoteos_client/features/firewall/data/remote_firewall_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('uses typed firewall status, rules and credential-confirmed operations',
      () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/login')
        return http.Response(jsonEncode(_login), 200);
      expect(request.headers['authorization'], 'Bearer access');
      switch ('${request.method} ${request.url.path}') {
        case 'GET /api/v1/firewall/status':
          return http.Response(
              jsonEncode({
                'isAvailable': true,
                'isEnabled': true,
                'backend': 'ufw',
                'version': '0.36',
                'defaultIncomingPolicy': 'deny',
                'defaultOutgoingPolicy': 'allow',
                'problemCode': ''
              }),
              200);
        case 'GET /api/v1/firewall/rules':
          return http.Response(
              jsonEncode([
                {
                  'number': 1,
                  'action': 'allow',
                  'direction': 'in',
                  'protocol': 'tcp',
                  'source': 'any',
                  'destination': 'any',
                  'port': '22',
                  'addressFamily': 'IPv4'
                }
              ]),
              200);
        case 'PUT /api/v1/firewall/enabled':
          expect(jsonDecode(request.body), {
            'enabled': false,
            'credentialConfirmation': {'password': 'pw'}
          });
          return http.Response(
              jsonEncode({'success': true, 'problemCode': ''}), 200);
        case 'PUT /api/v1/firewall/defaults':
          expect(jsonDecode(request.body), {
            'incomingPolicy': 'deny',
            'outgoingPolicy': 'allow',
            'credentialConfirmation': null
          });
          return http.Response(
              jsonEncode({'success': true, 'problemCode': ''}), 200);
        case 'POST /api/v1/firewall/rules':
          expect(jsonDecode(request.body), {
            'action': 'allow',
            'direction': 'in',
            'protocol': 'tcp',
            'source': 'any',
            'destination': 'any',
            'port': '22',
            'credentialConfirmation': {'password': 'pw'}
          });
          return http.Response(
              jsonEncode({'success': true, 'problemCode': ''}), 200);
        case 'PUT /api/v1/firewall/rules/1':
          expect(jsonDecode(request.body), {
            'action': 'allow',
            'direction': 'in',
            'protocol': 'tcp',
            'source': '192.0.2.10',
            'destination': 'any',
            'port': '8000:8080',
            'credentialConfirmation': null
          });
          return http.Response(
              jsonEncode({'success': true, 'problemCode': ''}), 200);
        case 'DELETE /api/v1/firewall/rules/1':
          expect(jsonDecode(request.body), {
            'credentialConfirmation': {'password': 'pw'}
          });
          return http.Response(
              jsonEncode({'success': true, 'problemCode': ''}), 200);
      }
      throw StateError('Unexpected $request');
    });
    final auth = AuthNotifier(httpClient: client);
    addTearDown(auth.dispose);
    await auth.login(
        serverUrl: 'https://remoteos.test', username: 'a', password: 'p');
    final api = RemoteFirewallApi(RemoteOsApi(auth));
    final status = await api.status();
    expect(status.isAvailable && status.isEnabled, isTrue);
    expect(status.backend, 'ufw');
    expect(status.defaultIncomingPolicy, 'deny');
    expect(status.defaultOutgoingPolicy, 'allow');
    final rules = await api.rules();
    expect(rules.single.number, 1);
    expect(rules.single.addressFamily, 'IPv4');
    expect(rules.single.port, '22');
    expect((await api.setEnabled(false, password: 'pw')).success, isTrue);
    expect((await api.setDefaults('deny', 'allow')).success, isTrue);
    const input = FirewallRuleInput(
        action: 'allow',
        direction: 'in',
        protocol: 'tcp',
        source: 'any',
        destination: 'any',
        port: '22');
    expect((await api.createRule(input, password: 'pw')).success, isTrue);
    const updated = FirewallRuleInput(
        action: 'allow',
        direction: 'in',
        protocol: 'tcp',
        source: '192.0.2.10',
        destination: 'any',
        port: '8000:8080');
    expect((await api.updateRule(1, updated)).success, isTrue);
    expect((await api.deleteRule(1, password: 'pw')).success, isTrue);
  });
}

const _login = {
  'user': {'username': 'a'},
  'workspace': {'id': 'w', 'name': 'W'},
  'tokens': {
    'accessToken': 'access',
    'refreshToken': 'refresh',
    'accessTokenExpiresAt': '2026-08-28T16:00:00Z',
    'refreshTokenExpiresAt': '2026-09-28T16:00:00Z'
  }
};
