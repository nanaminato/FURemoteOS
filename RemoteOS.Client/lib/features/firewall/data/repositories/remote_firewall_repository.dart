// Firewall repository implementation (ARCHITECTURE.md § 11).
//
// Wraps [RemoteFirewallApi] and maps service-layer operation results into the
// domain-level [FirewallOpResult].  The repository owns no presentation state.

import '../../domain/firewall_repository.dart';
import '../../data/remote_firewall_api.dart';

class RemoteFirewallRepository implements FirewallRepository {
  RemoteFirewallRepository(this._api);

  final RemoteFirewallApi _api;

  @override
  Future<FirewallStatus> getStatus() => _api.status();

  @override
  Future<List<FirewallRule>> listRules() => _api.rules();

  @override
  Future<FirewallOpResult> setEnabled(
    bool enabled, {
    String? passwordConfirmation,
  }) async {
    final result =
        await _api.setEnabled(enabled, password: passwordConfirmation);
    return FirewallOpResult(
      success: result.success,
      problemCode: result.problemCode,
    );
  }

  @override
  Future<FirewallOpResult> setDefaults(
    String incomingPolicy,
    String outgoingPolicy, {
    String? passwordConfirmation,
  }) async {
    final result = await _api.setDefaults(
      incomingPolicy,
      outgoingPolicy,
      password: passwordConfirmation,
    );
    return FirewallOpResult(
      success: result.success,
      problemCode: result.problemCode,
    );
  }

  @override
  Future<FirewallOpResult> createRule(
    FirewallRuleInput rule, {
    String? passwordConfirmation,
  }) async {
    final result = await _api.createRule(rule, password: passwordConfirmation);
    return FirewallOpResult(
      success: result.success,
      problemCode: result.problemCode,
    );
  }

  @override
  Future<FirewallOpResult> updateRule(
    int number,
    FirewallRuleInput rule, {
    String? passwordConfirmation,
  }) async {
    final result =
        await _api.updateRule(number, rule, password: passwordConfirmation);
    return FirewallOpResult(
      success: result.success,
      problemCode: result.problemCode,
    );
  }

  @override
  Future<FirewallOpResult> deleteRule(
    int number, {
    String? passwordConfirmation,
  }) async {
    final result =
        await _api.deleteRule(number, password: passwordConfirmation);
    return FirewallOpResult(
      success: result.success,
      problemCode: result.problemCode,
    );
  }
}
