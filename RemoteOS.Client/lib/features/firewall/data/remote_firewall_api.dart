import '../../../core/network/remoteos_api.dart';

/// Typed UFW firewall REST boundary. All payloads stay structured; the client
/// never composes UFW command text. Passwords are one-shot confirmations that
/// are only attached to the request they were collected for.
class RemoteFirewallApi {
  RemoteFirewallApi(this._api);
  final RemoteOsApi _api;

  Future<FirewallStatus> status() async => FirewallStatus.fromJson(
      _map(await _api.getJson('/api/v1/firewall/status')));

  Future<List<FirewallRule>> rules() async => _list(
          await _api.getJson('/api/v1/firewall/rules'))
      .map((value) => FirewallRule.fromJson(_map(value)))
      .toList();

  Future<FirewallOperationResult> setEnabled(bool enabled,
          {String? password}) async =>
      FirewallOperationResult.fromJson(_map(await _api.sendJson(
          'PUT', '/api/v1/firewall/enabled',
          body: {
            'enabled': enabled,
            'credentialConfirmation': _credential(password)
          })));

  Future<FirewallOperationResult> setDefaults(String incomingPolicy,
          String outgoingPolicy,
          {String? password}) async =>
      FirewallOperationResult.fromJson(_map(await _api.sendJson(
          'PUT', '/api/v1/firewall/defaults',
          body: {
            'incomingPolicy': incomingPolicy,
            'outgoingPolicy': outgoingPolicy,
            'credentialConfirmation': _credential(password)
          })));

  Future<FirewallOperationResult> createRule(FirewallRuleInput rule,
          {String? password}) async =>
      FirewallOperationResult.fromJson(_map(await _api.sendJson('POST',
          '/api/v1/firewall/rules',
          body: {...rule.toJson(), 'credentialConfirmation': _credential(password)})));

  Future<FirewallOperationResult> updateRule(int number, FirewallRuleInput rule,
          {String? password}) async =>
      FirewallOperationResult.fromJson(_map(await _api.sendJson(
          'PUT', '/api/v1/firewall/rules/$number',
          body: {...rule.toJson(), 'credentialConfirmation': _credential(password)})));

  Future<FirewallOperationResult> deleteRule(int number,
          {String? password}) async =>
      FirewallOperationResult.fromJson(_map(await _api.sendJson(
          'DELETE', '/api/v1/firewall/rules/$number',
          body: {'credentialConfirmation': _credential(password)})));

  static Map<String, String>? _credential(String? password) =>
      password == null ? null : {'password': password};
}

class FirewallStatus {
  const FirewallStatus(
      {required this.isAvailable,
      required this.isEnabled,
      required this.backend,
      required this.problemCode,
      this.version,
      this.defaultIncomingPolicy,
      this.defaultOutgoingPolicy});
  final bool isAvailable;
  final bool isEnabled;
  final String backend;
  final String problemCode;
  final String? version;
  final String? defaultIncomingPolicy;
  final String? defaultOutgoingPolicy;
  factory FirewallStatus.fromJson(Map<String, dynamic> json) => FirewallStatus(
      isAvailable: json['isAvailable'] == true,
      isEnabled: json['isEnabled'] == true,
      backend: json['backend']?.toString() ?? '',
      problemCode: json['problemCode']?.toString() ?? '',
      version: json['version']?.toString(),
      defaultIncomingPolicy: json['defaultIncomingPolicy']?.toString(),
      defaultOutgoingPolicy: json['defaultOutgoingPolicy']?.toString());
}

class FirewallRule {
  const FirewallRule(
      {required this.number,
      required this.action,
      required this.direction,
      required this.protocol,
      required this.source,
      required this.destination,
      required this.port,
      required this.addressFamily});
  final int number;
  final String action, direction, protocol, source, destination, port;
  final String addressFamily;
  factory FirewallRule.fromJson(Map<String, dynamic> json) => FirewallRule(
      number: _int(json['number']),
      action: json['action']?.toString() ?? '',
      direction: json['direction']?.toString() ?? '',
      protocol: json['protocol']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      port: json['port']?.toString() ?? '',
      addressFamily: json['addressFamily']?.toString() ?? 'IPv4');
}

/// Structural rule fields shared by create and update payloads.
class FirewallRuleInput {
  const FirewallRuleInput(
      {required this.action,
      required this.direction,
      required this.protocol,
      required this.source,
      required this.destination,
      required this.port});
  final String action, direction, protocol, source, destination, port;
  Map<String, dynamic> toJson() => {
        'action': action,
        'direction': direction,
        'protocol': protocol,
        'source': source,
        'destination': destination,
        'port': port
      };
}

class FirewallOperationResult {
  const FirewallOperationResult(
      {required this.success, required this.problemCode});
  final bool success;
  final String problemCode;
  factory FirewallOperationResult.fromJson(Map<String, dynamic> json) =>
      FirewallOperationResult(
          success: json['success'] == true,
          problemCode: json['problemCode']?.toString() ?? '');
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : const {};
List<Object?> _list(Object? value) =>
    value is List ? value.cast<Object?>() : const [];
int _int(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;
