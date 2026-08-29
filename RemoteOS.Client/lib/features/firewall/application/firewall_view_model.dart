// Firewall ViewModel (ARCHITECTURE.md § 9).
//
// Presentation state is exposed as an immutable [FirewallUiState] via
// [ValueNotifier]; user intents are [Command]s.
// Repository I/O is delegated to [FirewallRepository].
//
// Hooks that require Flutter UI (request password, open rule editor) are
// exposed as callbacks installed by the owning View — this keeps
// BuildContext / Navigator / showDialog out of the VM (AGENTS.md § 18).

import 'package:command_it/command_it.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

import '../../../app/dependency_injection.dart' as app_di;
import '../../../core/auth/auth_service.dart';
import '../../../core/commands/base_view_model.dart';
import '../data/remote_firewall_api.dart';
import '../domain/firewall_repository.dart';
import '../domain/firewall_ui_state.dart';

/// Callback: request a one-shot password for the pending privileged op.
/// Returns null if the user cancelled.
typedef FirewallRequestPassword = Future<String?> Function();

/// Callback: open the add/edit rule modal.  [editing] = true when editing.
/// The callback completes with true if changes should be committed.
typedef FirewallShowRuleEditor = Future<bool> Function(bool editing);

// ---- Default no-op callbacks, never null ----
Future<String?> _noopPassword() async => null;
Future<bool> _noopRuleEditor(bool _) async => false;

/// ViewModel factory so get_it can inject dependencies.
FirewallViewModel createFirewallViewModel() => FirewallViewModel(
      repository: app_di.getService<FirewallRepository>(),
      isRoot: app_di.getService<AuthNotifier>().current.username == 'root',
    );

class FirewallViewModel extends ViewModel {
  FirewallViewModel({
    required FirewallRepository repository,
    required bool isRoot,
  })  : _repository = repository,
        _isRoot = isRoot {
    trackDisposable(state);
    trackDisposable(startCommand);
    trackDisposable(refreshCommand);
    trackDisposable(enableCommand);
    trackDisposable(disableCommand);
    trackDisposable(saveDefaultsCommand);
    trackDisposable(addRuleCommand);
    trackDisposable(updateRuleCommand);
    trackDisposable(deleteRuleCommand);
    // Static option mirrors (copied from repository for convenience access
    // by the View without importing the repository interface directly).
    policies = FirewallRepository.policies;
    actions = FirewallRepository.actions;
    directions = FirewallRepository.directions;
    protocols = FirewallRepository.protocols;
  }

  final FirewallRepository _repository;
  final bool _isRoot;

  // ---- View-installed callbacks ----
  FirewallRequestPassword requestPassword = _noopPassword;
  FirewallShowRuleEditor showRuleEditor = _noopRuleEditor;

  // ---- Static option lists ----
  late final List<String> policies;
  late final List<String> actions;
  late final List<String> directions;
  late final List<String> protocols;

  // ---- Presentation state ----
  final ValueNotifier<FirewallUiState> state =
      ValueNotifier<FirewallUiState>(FirewallUiState.initial());

  FirewallUiState get _s => state.value;
  void _mutate(FirewallUiState Function(FirewallUiState s) fn) {
    state.value = fn(state.value);
  }

  // ---- Convenience getters mirroring the old _FirewallVm API ----
  String get statusText => _s.statusText;
  bool get isAvailable => _s.isAvailable;
  bool get isEnabled => _s.isEnabled;
  bool get isLoading => _s.isLoading;
  String get incomingPolicy => _s.incomingPolicy;
  String get outgoingPolicy => _s.outgoingPolicy;
  List<FirewallRule> get rules => _s.rules;
  FirewallRule? get selectedRule => _s.selectedRule;

  // ---- Enabled-state helpers (used by the View to gate toolbar actions) ----
  bool canRefresh() => !_s.isLoading;
  bool canEnable() => _s.canManage && !_s.isEnabled && !_s.isLoading;
  bool canDisable() => _s.canManage && _s.isEnabled && !_s.isLoading;
  bool canManageAction() => _s.canManage && !_s.isLoading;
  bool canEditRule() =>
      _s.canManage && !_s.isLoading && _s.selectedRule != null;

  // ---- Commands ----
  //
  // command_it v1.x does not expose a `canExecuteListenable` parameter on
  // command factories, so toolbar-level enable logic lives in the helpers
  // above; the Command objects themselves still provide execution-state
  // tracking (isRunning) which the View can gate on.

  late final startCommand = Command.createAsyncNoParamNoResult(() async {
    _mutate((s) => s.copyWith(
          statusText: 'firewall.status.loading'.tr(),
        ));
    await _refreshInternal();
  });

  late final refreshCommand =
      Command.createAsyncNoParamNoResult(_refreshInternal);

  late final enableCommand =
      Command.createAsyncNoParamNoResult(() => _applyInternal(
            (password) =>
                _repository.setEnabled(true, passwordConfirmation: password),
          ));

  late final disableCommand =
      Command.createAsyncNoParamNoResult(() => _applyInternal(
            (password) =>
                _repository.setEnabled(false, passwordConfirmation: password),
          ));

  late final saveDefaultsCommand =
      Command.createAsyncNoParamNoResult(() => _applyInternal(
            (password) => _repository.setDefaults(
              _s.incomingPolicy,
              _s.outgoingPolicy,
              passwordConfirmation: password,
            ),
          ));

  late final addRuleCommand = Command.createAsyncNoParamNoResult(() async {
    final committed = await showRuleEditor(false);
    if (committed) await _refreshInternal();
  });

  late final updateRuleCommand = Command.createAsyncNoParamNoResult(() async {
    final committed = await showRuleEditor(true);
    if (committed) await _refreshInternal();
  });

  late final deleteRuleCommand = Command.createAsyncNoParamNoResult(() async {
    final number = _s.selectedRuleNumber;
    if (number == null) return;
    await _applyInternal(
      (password) =>
          _repository.deleteRule(number, passwordConfirmation: password),
    );
  });

  // ---- State mutators used by the View (not Commands) ----

  void selectRule(FirewallRule? rule) {
    _mutate((s) => s.copyWith(
          selectedRuleNumber: rule?.number,
          clearSelectedRule: rule == null,
        ));
  }

  void setIncomingPolicy(String value) {
    _mutate((s) => s.copyWith(incomingPolicy: value));
  }

  void setOutgoingPolicy(String value) {
    _mutate((s) => s.copyWith(outgoingPolicy: value));
  }

  // ---- Helpers shared by rule editor dialog ----

  /// Build a [FirewallRuleInput] after validating address + port.  Returns
  /// null and updates the status text with a validation message on failure.
  FirewallRuleInput? buildRule({
    required String action,
    required String direction,
    required String protocol,
    required String source,
    required String destination,
    required String port,
  }) {
    if (!isValidEndpoint(source) || !isValidEndpoint(destination)) {
      _mutate((s) => s.copyWith(
            statusText: 'firewall.validation.address_invalid'.tr(),
          ));
      return null;
    }
    final trimmedPort = port.trim();
    if (trimmedPort.isNotEmpty && !isValidPort(trimmedPort)) {
      _mutate((s) => s.copyWith(
            statusText: 'firewall.validation.port_invalid'.tr(),
          ));
      return null;
    }
    return FirewallRuleInput(
      action: action,
      direction: direction,
      protocol: protocol,
      source: normalizeEndpoint(source),
      destination: normalizeEndpoint(destination),
      port: trimmedPort.isEmpty ? 'any' : trimmedPort,
    );
  }

  /// Commit an add-operation result (called from the rule-editor dialog).
  Future<bool> commitAdd({
    required String action,
    required String direction,
    required String protocol,
    required String source,
    required String destination,
    required String port,
  }) async {
    final input = buildRule(
      action: action,
      direction: direction,
      protocol: protocol,
      source: source,
      destination: destination,
      port: port,
    );
    if (input == null) return false;
    return _applyInternal(
      (password) =>
          _repository.createRule(input, passwordConfirmation: password),
    );
  }

  /// Commit an update-operation result (called from the rule-editor dialog).
  Future<bool> commitUpdate({
    required String action,
    required String direction,
    required String protocol,
    required String source,
    required String destination,
    required String port,
  }) async {
    final number = _s.selectedRuleNumber;
    if (number == null) return false;
    final input = buildRule(
      action: action,
      direction: direction,
      protocol: protocol,
      source: source,
      destination: destination,
      port: port,
    );
    if (input == null) return false;
    return _applyInternal(
      (password) =>
          _repository.updateRule(number, input, passwordConfirmation: password),
    );
  }

  // ---- Validation helpers (mirror the original Avalonia helpers) ----

  static String normalizeEndpoint(String value) =>
      value.trim().isEmpty ? 'any' : value.trim();

  static bool isValidEndpoint(String value) {
    final normalized = normalizeEndpoint(value);
    if (normalized.toLowerCase() == 'any' ||
        normalized.toLowerCase() == 'anywhere') {
      return true;
    }
    final slash = normalized.indexOf('/');
    final address = slash < 0 ? normalized : normalized.substring(0, slash);
    final isV6 = address.contains(':');
    if (!_isIpAddress(address, isV6)) return false;
    if (slash < 0) return true;
    final prefix = int.tryParse(normalized.substring(slash + 1));
    return prefix != null && prefix >= 0 && prefix <= (isV6 ? 128 : 32);
  }

  static bool _isIpAddress(String value, bool isV6) {
    if (isV6) {
      try {
        Uri.parseIPv6Address(value);
        return true;
      } on FormatException {
        return false;
      }
    }
    final parts = value.split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      if (part.isEmpty ||
          part.length > 3 ||
          part.codeUnits.any((code) => code < 0x30 || code > 0x39)) {
        return false;
      }
      if (int.parse(part) > 255) return false;
    }
    return true;
  }

  static bool isValidPort(String value) {
    final parts = value.split(':');
    if (parts.length != 1 && parts.length != 2) return false;
    final numbers = <int>[];
    for (final part in parts) {
      final port = int.tryParse(part);
      if (port == null || port <= 0 || port > 65535) return false;
      numbers.add(port);
    }
    return parts.length == 1 || numbers[0] <= numbers[1];
  }

  static String find(List<String> options, String? value, String fallback) {
    for (final option in options) {
      if (option.toLowerCase() == value?.toLowerCase()) return option;
    }
    for (final option in options) {
      if (option == fallback) return option;
    }
    return options.first;
  }

  // ---- Internal refresh + apply flow ----

  Future<void> _refreshInternal() async {
    if (_s.isLoading) return;
    _mutate((s) => s.copyWith(isLoading: true));
    try {
      final status = await _repository.getStatus();
      final rules = await _repository.listRules();
      _mutate((s) => s.copyWith(
            isAvailable: status.isAvailable,
            isEnabled: status.isEnabled,
            incomingPolicy: find(FirewallRepository.policies,
                status.defaultIncomingPolicy, 'deny'),
            outgoingPolicy: find(FirewallRepository.policies,
                status.defaultOutgoingPolicy, 'allow'),
            rules: rules,
            clearSelectedRule: true,
            statusText: status.isAvailable
                ? ((status.isEnabled
                        ? 'firewall.status.ready_enabled'
                        : 'firewall.status.ready_disabled')
                    .tr(args: [status.backend, status.version ?? '']))
                : 'firewall.status.unavailable'.tr(args: [status.problemCode]),
          ));
    } catch (error) {
      _mutate((s) => FirewallUiState.initial().copyWith(
            statusText: 'firewall.status.failed'.tr(args: ['$error']),
          ));
    } finally {
      _mutate((s) => s.copyWith(isLoading: false));
    }
  }

  /// Runs [operation] with an optional password confirmation and reloads
  /// state on success.  Returns true on success.
  Future<bool> _applyInternal(
    Future<FirewallOpResult> Function(String? password) operation,
  ) async {
    String? password;
    if (!_isRoot) {
      password = await requestPassword();
      if (password == null) return false;
    }
    _mutate((s) => s.copyWith(isLoading: true));
    var success = false;
    try {
      final result = await operation(password);
      _mutate((s) => s.copyWith(
            statusText: result.success
                ? 'firewall.operation.succeeded'.tr()
                : 'firewall.operation.failed'.tr(args: [result.problemCode]),
          ));
      success = result.success;
    } catch (error) {
      _mutate((s) => s.copyWith(
            statusText: 'firewall.operation.failed'.tr(args: ['$error']),
          ));
    } finally {
      _mutate((s) => s.copyWith(isLoading: false));
    }
    if (success) await _refreshInternal();
    return success;
  }
}
