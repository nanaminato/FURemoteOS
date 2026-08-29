// Firewall domain repository (ARCHITECTURE.md § 11).
//
// The repository is the ViewModel's canonical access point for firewall
// state and mutation operations.  DTOs are kept below this boundary; the
// repository maps errors into typed [FirewallFailure] results and exposes
// the data model used by presentation (which is currently the same as the
// service DTO shape to avoid unnecessary adapter layers during migration).

import '../data/remote_firewall_api.dart';

/// Result wrapper for privileged firewall operations that can fail with
/// permission/validation/server-side problems.
class FirewallOpResult {
  const FirewallOpResult({required this.success, required this.problemCode});
  final bool success;
  final String problemCode;
}

/// Firewall repository interface.  ViewModels depend on this interface.
///
/// Privileged operations accept a one-shot [passwordConfirmation].  The
/// ViewModel is responsible for collecting it via a callback hook; the
/// repository must never retain or log a credential.
abstract interface class FirewallRepository {
  // ---- Static option lists (mirror the Avalonia ViewModel) ----
  static const List<String> policies = ['allow', 'deny', 'reject'];
  static const List<String> actions = ['allow', 'deny', 'reject', 'limit'];
  static const List<String> directions = ['in', 'out'];
  static const List<String> protocols = ['tcp', 'udp', 'any'];

  // ---- Status + rules (read) ----
  Future<FirewallStatus> getStatus();
  Future<List<FirewallRule>> listRules();

  // ---- Enable / disable + defaults (write) ----
  Future<FirewallOpResult> setEnabled(bool enabled,
      {String? passwordConfirmation});
  Future<FirewallOpResult> setDefaults(
    String incomingPolicy,
    String outgoingPolicy, {
    String? passwordConfirmation,
  });

  // ---- Rule CRUD (write) ----
  Future<FirewallOpResult> createRule(FirewallRuleInput rule,
      {String? passwordConfirmation});
  Future<FirewallOpResult> updateRule(
    int number,
    FirewallRuleInput rule, {
    String? passwordConfirmation,
  });
  Future<FirewallOpResult> deleteRule(int number,
      {String? passwordConfirmation});
}
