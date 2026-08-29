// Firewall UI state (ARCHITECTURE.md § 12 — Presentation State).
//
// Immutable projection consumed by the View.  The ViewModel updates this
// via a single [ValueNotifier<FirewallUiState>] so Views can react to
// changes by watching a single notifier (matches docker/notepad pattern).

import 'package:flutter/foundation.dart';

import '../data/remote_firewall_api.dart';

enum FirewallDialogKind { none, password, addRule, editRule }

@immutable
class FirewallUiState {
  const FirewallUiState({
    required this.statusText,
    required this.isAvailable,
    required this.isEnabled,
    required this.isLoading,
    required this.incomingPolicy,
    required this.outgoingPolicy,
    required this.rules,
    required this.selectedRuleNumber,
  });

  factory FirewallUiState.initial() => const FirewallUiState(
        statusText: '',
        isAvailable: false,
        isEnabled: false,
        isLoading: false,
        incomingPolicy: 'deny',
        outgoingPolicy: 'allow',
        rules: [],
        selectedRuleNumber: null,
      );

  final String statusText;
  final bool isAvailable;
  final bool isEnabled;
  final bool isLoading;
  final String incomingPolicy;
  final String outgoingPolicy;
  final List<FirewallRule> rules;
  final int? selectedRuleNumber;

  FirewallRule? get selectedRule {
    final n = selectedRuleNumber;
    if (n == null) return null;
    for (final r in rules) {
      if (r.number == n) return r;
    }
    return null;
  }

  bool get canManage => isAvailable && !isLoading;

  FirewallUiState copyWith({
    String? statusText,
    bool? isAvailable,
    bool? isEnabled,
    bool? isLoading,
    String? incomingPolicy,
    String? outgoingPolicy,
    List<FirewallRule>? rules,
    int? selectedRuleNumber,
    bool clearSelectedRule = false,
  }) {
    return FirewallUiState(
      statusText: statusText ?? this.statusText,
      isAvailable: isAvailable ?? this.isAvailable,
      isEnabled: isEnabled ?? this.isEnabled,
      isLoading: isLoading ?? this.isLoading,
      incomingPolicy: incomingPolicy ?? this.incomingPolicy,
      outgoingPolicy: outgoingPolicy ?? this.outgoingPolicy,
      rules: rules ?? this.rules,
      selectedRuleNumber: clearSelectedRule
          ? null
          : (selectedRuleNumber ?? this.selectedRuleNumber),
    );
  }
}
