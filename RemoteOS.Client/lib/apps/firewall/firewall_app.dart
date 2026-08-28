import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/network/remoteos_api.dart';
import '../../core/theme/theme_service.dart';
import '../../core/window_manager/modal_manager.dart';
import '../../core/window_manager/window_manager.dart';
import '../../features/firewall/data/remote_firewall_api.dart';

/// Firewall, migrated from the Avalonia `FirewallApp` (Linux UFW editor).
/// All state and typed operations live in [_FirewallVm]; destructive changes
/// collect a one-shot password that is never retained.
class FirewallApp extends ConsumerStatefulWidget {
  const FirewallApp({super.key});

  @override
  ConsumerState<FirewallApp> createState() => _FirewallAppState();
}

class _FirewallAppState extends ConsumerState<FirewallApp> {
  _FirewallVm? vm;

  @override
  void initState() {
    super.initState();
    final session = ref.read(authProvider);
    if (session.isAuthenticated) {
      vm = _FirewallVm(RemoteFirewallApi(ref.read(remoteOsApiProvider)),
          isRoot: session.username == 'root')
        ..requestPassword = _requestPassword
        ..start();
    }
  }

  @override
  void dispose() {
    vm?.dispose();
    super.dispose();
  }

  String get _ownerId => RemoteWindowScope.of(context).window.id;

  Future<String?> _requestPassword() async =>
      await ref.read(modalManagerProvider).open<String>(
          ownerId: _ownerId,
          spec: ModalSpec(
              title: 'firewall.password_dialog.title'.tr(),
              icon: Icons.password_outlined,
              preferredSize: const Size(420, 180),
              child: const _PasswordDialog()));

  Future<void> _showRuleEditor(bool editing) => ref
      .read(modalManagerProvider)
      .open<bool>(
          ownerId: _ownerId,
          spec: ModalSpec(
              title: (editing
                      ? 'firewall.rule.edit_dialog_title'
                      : 'firewall.rule.add_dialog_title')
                  .tr(),
              icon: Icons.rule_outlined,
              preferredSize: const Size(460, 560),
              child: _RuleEditorDialog(vm: vm!, editing: editing)));

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    final session = ref.watch(authProvider);
    final model = vm;
    if (!session.isAuthenticated || model == null) {
      return Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
              child: Text('firewall.login_required'.tr(),
                  style: TextStyle(color: palette.textPrimary))));
    }
    return AnimatedBuilder(
        animation: model,
        builder: (context, _) {
          final canManage = model.isAvailable && !model.isLoading;
          return Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                              onPressed:
                                  model.isLoading ? null : model.refresh,
                              child: Text('common.refresh'.tr())),
                        ]),
                    const SizedBox(height: 8),
                    Text(model.statusText,
                        style: TextStyle(color: palette.textPrimary)),
                    const SizedBox(height: 12),
                    Text('firewall.warning'.tr(),
                        style: TextStyle(
                            fontSize: 12, color: palette.textTertiary)),
                    const SizedBox(height: 14),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          OutlinedButton(
                              onPressed: canManage && !model.isEnabled
                                  ? model.enable
                                  : null,
                              child: Text('firewall.enable'.tr())),
                          const SizedBox(width: 10),
                          OutlinedButton(
                              onPressed: canManage && model.isEnabled
                                  ? model.disable
                                  : null,
                              child: Text('firewall.disable'.tr())),
                          const SizedBox(width: 16),
                          _ChoiceField(
                              label: 'firewall.default_incoming'.tr(),
                              value: model.incomingPolicy,
                              choices: _FirewallVm.policies,
                              width: 150,
                              palette: palette,
                              onChanged: (value) => model
                                  .setIncomingPolicy(value ?? 'deny')),
                          const SizedBox(width: 10),
                          _ChoiceField(
                              label: 'firewall.default_outgoing'.tr(),
                              value: model.outgoingPolicy,
                              choices: _FirewallVm.policies,
                              width: 150,
                              palette: palette,
                              onChanged: (value) => model
                                  .setOutgoingPolicy(value ?? 'allow')),
                          const SizedBox(width: 16),
                          OutlinedButton(
                              onPressed: canManage ? model.saveDefaults : null,
                              child: Text('firewall.save_defaults'.tr())),
                        ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      OutlinedButton(
                          onPressed: canManage
                              ? () => _showRuleEditor(false)
                              : null,
                          child: Text('firewall.rule.add'.tr())),
                      const SizedBox(width: 8),
                      OutlinedButton(
                          onPressed: canManage && model.selectedRule != null
                              ? () => _showRuleEditor(true)
                              : null,
                          child: Text('firewall.rule.update'.tr())),
                    ]),
                    const SizedBox(height: 10),
                    Expanded(
                        child: _RuleTable(
                            vm: model, palette: palette)),
                    const SizedBox(height: 8),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: _dangerButton(
                            'firewall.rule.delete'.tr(),
                            palette,
                            canManage && model.selectedRule != null
                                ? model.deleteRule
                                : null)),
                  ]));
        });
  }
}

Widget _dangerButton(String label, ThemePalette palette, VoidCallback? onPressed) =>
    OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(foregroundColor: palette.danger),
        child: Text(label));

/// Labelled dropdown, mirroring the Avalonia `ChoiceField`.
class _ChoiceField extends StatelessWidget {
  const _ChoiceField(
      {required this.label,
      required this.value,
      required this.choices,
      required this.palette,
      this.width,
      this.onChanged});

  final String label;
  final String value;
  final List<String> choices;
  final ThemePalette palette;
  final double? width;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
      width: width,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    TextStyle(fontSize: 13, color: palette.textSecondary)),
            DropdownButtonFormField<String>(
                value: choices.contains(value) ? value : choices.first,
                items: [
                  for (final choice in choices)
                    DropdownMenuItem(
                        value: choice,
                        child: Text('firewall.choice.$choice'.tr()))
                ],
                onChanged: onChanged,
                decoration: const InputDecoration(isDense: true)),
          ]));
}

/// Single-select rule table (Avalonia DataGrid columns).
class _RuleTable extends StatelessWidget {
  const _RuleTable({required this.vm, required this.palette});

  final _FirewallVm vm;
  final ThemePalette palette;

  static const _columns = <(String, double)>[
    ('firewall.rule.number', 70),
    ('firewall.rule.action', 100),
    ('firewall.rule.direction', 100),
    ('firewall.rule.protocol', 100),
    ('firewall.rule.address_family', 120),
    ('firewall.rule.source', 210),
    ('firewall.rule.destination', 210),
    ('firewall.rule.port', 140),
  ];

  String _cell(FirewallRule rule, int index) => switch (index) {
        0 => '${rule.number}',
        1 => rule.action,
        2 => rule.direction,
        3 => rule.protocol,
        4 => rule.addressFamily,
        5 => rule.source,
        6 => rule.destination,
        _ => rule.port,
      };

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1050),
          child: DataTable(
              headingRowColor:
                  WidgetStatePropertyAll(palette.surfaceSunken),
              headingRowHeight: 34,
              dataRowMinHeight: 34,
              dataRowMaxHeight: 34,
              columnSpacing: 18,
              columns: [
                for (final (key, _) in _columns)
                  DataColumn(
                      label: Text(key.tr(),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: palette.textSecondary)))
              ],
              rows: [
                for (final rule in vm.rules)
                  DataRow(
                      selected: identical(rule, vm.selectedRule),
                      onSelectChanged: (value) =>
                          vm.selectRule(value == true ? rule : null),
                      cells: [
                        for (var index = 0; index < _columns.length; index++)
                          DataCell(SizedBox(
                              width: _columns[index].$2,
                              child: Text(_cell(rule, index),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: palette.textPrimary))))
                      ])
              ])));
}

/// One-shot password confirmation (Avalonia `RequestPasswordAsync` dialog).
class _PasswordDialog extends ConsumerStatefulWidget {
  const _PasswordDialog();

  @override
  ConsumerState<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends ConsumerState<_PasswordDialog> {
  final password = TextEditingController();

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    final windowId = RemoteModalScope.of(context).windowId;
    return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('firewall.password_dialog.message'.tr(),
                  style: TextStyle(color: palette.textPrimary)),
              const SizedBox(height: 12),
              TextField(
                  controller: password,
                  obscureText: true,
                  autofocus: true,
                  onSubmitted: (_) => ref
                      .read(modalManagerProvider)
                      .complete(windowId, password.text),
                  decoration: InputDecoration(
                      hintText: 'firewall.password_placeholder'.tr(),
                      isDense: true)),
              const Spacer(),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                    onPressed: () =>
                        ref.read(modalManagerProvider).dismiss(windowId),
                    child: Text('common.cancel'.tr())),
                const SizedBox(width: 8),
                FilledButton(
                    onPressed: () => ref
                        .read(modalManagerProvider)
                        .complete(windowId, password.text),
                    child: Text('common.ok'.tr())),
              ]),
            ]));
  }
}

/// Add/edit rule editor (Avalonia `ShowRuleEditorAsync` dialog, 460×560).
class _RuleEditorDialog extends ConsumerStatefulWidget {
  const _RuleEditorDialog({required this.vm, required this.editing});

  final _FirewallVm vm;
  final bool editing;

  @override
  ConsumerState<_RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends ConsumerState<_RuleEditorDialog> {
  late String action = widget.editing
      ? _FirewallVm.find(_FirewallVm.actions, widget.vm.selectedRule?.action, 'allow')
      : 'allow';
  late String direction = widget.editing
      ? _FirewallVm.find(
          _FirewallVm.directions, widget.vm.selectedRule?.direction, 'in')
      : 'in';
  late String protocol = widget.editing
      ? _FirewallVm.find(
          _FirewallVm.protocols, widget.vm.selectedRule?.protocol, 'tcp')
      : 'tcp';
  late final source = TextEditingController(
      text: widget.editing
          ? _editable(widget.vm.selectedRule?.source)
          : '');
  late final destination = TextEditingController(
      text: widget.editing
          ? _editable(widget.vm.selectedRule?.destination)
          : '');
  late final port = TextEditingController(
      text: widget.editing ? _editable(widget.vm.selectedRule?.port) : '');

  static String _editable(String? value) =>
      value == null || value == 'any' ? '' : value;

  @override
  void dispose() {
    source.dispose();
    destination.dispose();
    port.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = widget.editing
        ? await widget.vm.updateRule(
            action: action,
            direction: direction,
            protocol: protocol,
            source: source.text,
            destination: destination.text,
            port: port.text)
        : await widget.vm.addRule(
            action: action,
            direction: direction,
            protocol: protocol,
            source: source.text,
            destination: destination.text,
            port: port.text);
    if (ok && mounted) {
      ref
          .read(modalManagerProvider)
          .complete(RemoteModalScope.of(context).windowId, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    final windowId = RemoteModalScope.of(context).windowId;
    return AnimatedBuilder(
        animation: widget.vm,
        builder: (context, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('firewall.rule.help'.tr(),
                      style: TextStyle(
                          fontSize: 12, color: palette.textTertiary)),
                  const SizedBox(height: 12),
                  Text(widget.vm.statusText,
                      style: TextStyle(color: palette.textPrimary)),
                  const SizedBox(height: 12),
                  Expanded(
                      child: SingleChildScrollView(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                        _ChoiceField(
                            label: 'firewall.rule.action'.tr(),
                            value: action,
                            choices: _FirewallVm.actions,
                            width: 360,
                            palette: palette,
                            onChanged: (value) =>
                                setState(() => action = value ?? 'allow')),
                        const SizedBox(height: 12),
                        _ChoiceField(
                            label: 'firewall.rule.direction'.tr(),
                            value: direction,
                            choices: _FirewallVm.directions,
                            width: 360,
                            palette: palette,
                            onChanged: (value) =>
                                setState(() => direction = value ?? 'in')),
                        const SizedBox(height: 12),
                        _ChoiceField(
                            label: 'firewall.rule.protocol'.tr(),
                            value: protocol,
                            choices: _FirewallVm.protocols,
                            width: 360,
                            palette: palette,
                            onChanged: (value) =>
                                setState(() => protocol = value ?? 'tcp')),
                        const SizedBox(height: 12),
                        Tooltip(
                            message:
                                'firewall.rule.source_tooltip'.tr(),
                            child: TextField(
                                controller: source,
                                decoration: InputDecoration(
                                    labelText: 'firewall.rule.source'.tr(),
                                    hintText:
                                        'firewall.rule.source_hint'.tr(),
                                    isDense: true))),
                        const SizedBox(height: 12),
                        Tooltip(
                            message:
                                'firewall.rule.destination_tooltip'.tr(),
                            child: TextField(
                                controller: destination,
                                decoration: InputDecoration(
                                    labelText:
                                        'firewall.rule.destination'.tr(),
                                    hintText:
                                        'firewall.rule.destination_hint'.tr(),
                                    isDense: true))),
                        const SizedBox(height: 12),
                        TextField(
                            controller: port,
                            decoration: InputDecoration(
                                labelText: 'firewall.rule.port'.tr(),
                                hintText: 'firewall.rule.port_hint'.tr(),
                                isDense: true)),
                      ]))),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    OutlinedButton(
                        onPressed: () => ref
                            .read(modalManagerProvider)
                            .dismiss(windowId),
                        child: Text('common.cancel'.tr())),
                    const SizedBox(width: 8),
                    FilledButton(
                        onPressed: widget.vm.isLoading ? null : _submit,
                        child: Text(widget.editing
                            ? 'firewall.rule.update'.tr()
                            : 'firewall.rule.add'.tr())),
                  ]),
                ])));
  }
}

/// View model: window-local UFW state plus safe typed operations.
class _FirewallVm extends ChangeNotifier {
  _FirewallVm(this.api, {required this.isRoot});

  final RemoteFirewallApi api;
  final bool isRoot;

  /// Provided by the window so a credential is collected only for the
  /// pending operation; the value is never retained.
  Future<String?> Function()? requestPassword;

  static const policies = ['allow', 'deny', 'reject'];
  static const actions = ['allow', 'deny', 'reject', 'limit'];
  static const directions = ['in', 'out'];
  static const protocols = ['tcp', 'udp', 'any'];

  final rules = <FirewallRule>[];
  FirewallRule? selectedRule;
  bool isAvailable = false;
  bool isEnabled = false;
  bool isLoading = false;
  String statusText = '';
  String incomingPolicy = 'deny';
  String outgoingPolicy = 'allow';

  void start() {
    statusText = 'firewall.status.loading'.tr();
    notifyListeners();
    refresh();
  }

  void selectRule(FirewallRule? rule) {
    if (identical(rule, selectedRule)) return;
    selectedRule = rule;
    notifyListeners();
  }

  void setIncomingPolicy(String value) {
    incomingPolicy = value;
    notifyListeners();
  }

  void setOutgoingPolicy(String value) {
    outgoingPolicy = value;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (isLoading) return;
    isLoading = true;
    notifyListeners();
    try {
      final status = await api.status();
      rules.clear();
      selectedRule = null;
      isAvailable = status.isAvailable;
      isEnabled = status.isEnabled;
      if (!status.isAvailable) {
        statusText =
            'firewall.status.unavailable'.tr(args: [status.problemCode]);
        return;
      }
      incomingPolicy =
          find(policies, status.defaultIncomingPolicy, 'deny');
      outgoingPolicy =
          find(policies, status.defaultOutgoingPolicy, 'allow');
      rules.addAll(await api.rules());
      statusText = (isEnabled
              ? 'firewall.status.ready_enabled'
              : 'firewall.status.ready_disabled')
          .tr(args: [status.backend, status.version ?? '']);
    } catch (error) {
      rules.clear();
      selectedRule = null;
      isAvailable = false;
      isEnabled = false;
      statusText = 'firewall.status.failed'.tr(args: ['$error']);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> enable() => _apply(
      (password) => api.setEnabled(true, password: password));

  Future<void> disable() => _apply(
      (password) => api.setEnabled(false, password: password));

  Future<void> saveDefaults() => _apply((password) => api.setDefaults(
      incomingPolicy, outgoingPolicy,
      password: password));

  Future<bool> addRule(
      {required String action,
      required String direction,
      required String protocol,
      required String source,
      required String destination,
      required String port}) {
    final input = _buildRule(
        action: action,
        direction: direction,
        protocol: protocol,
        source: source,
        destination: destination,
        port: port);
    if (input == null) return Future.value(false);
    return _apply((password) => api.createRule(input, password: password));
  }

  Future<bool> updateRule(
      {required String action,
      required String direction,
      required String protocol,
      required String source,
      required String destination,
      required String port}) {
    final number = selectedRule?.number;
    if (number == null) return Future.value(false);
    final input = _buildRule(
        action: action,
        direction: direction,
        protocol: protocol,
        source: source,
        destination: destination,
        port: port);
    if (input == null) return Future.value(false);
    return _apply(
        (password) => api.updateRule(number, input, password: password));
  }

  Future<void> deleteRule() async {
    final number = selectedRule?.number;
    if (number == null) return;
    await _apply(
        (password) => api.deleteRule(number, password: password));
  }

  FirewallRuleInput? _buildRule(
      {required String action,
      required String direction,
      required String protocol,
      required String source,
      required String destination,
      required String port}) {
    if (!isValidEndpoint(source) || !isValidEndpoint(destination)) {
      statusText = 'firewall.validation.address_invalid'.tr();
      notifyListeners();
      return null;
    }
    final trimmedPort = port.trim();
    if (trimmedPort.isNotEmpty && !isValidPort(trimmedPort)) {
      statusText = 'firewall.validation.port_invalid'.tr();
      notifyListeners();
      return null;
    }
    return FirewallRuleInput(
        action: action,
        direction: direction,
        protocol: protocol,
        source: normalizeEndpoint(source),
        destination: normalizeEndpoint(destination),
        port: trimmedPort.isEmpty ? 'any' : trimmedPort);
  }

  Future<bool> _apply(
      Future<FirewallOperationResult> Function(String? password)
          operation) async {
    String? password;
    if (!isRoot) {
      password = await (requestPassword?.call() ?? Future<String?>.value(null));
      if (password == null) return false;
    }
    isLoading = true;
    notifyListeners();
    var success = false;
    try {
      final result = await operation(password);
      statusText = result.success
          ? 'firewall.operation.succeeded'.tr()
          : 'firewall.operation.failed'.tr(args: [result.problemCode]);
      success = result.success;
    } catch (error) {
      statusText = 'firewall.operation.failed'.tr(args: ['$error']);
    } finally {
      isLoading = false;
      notifyListeners();
    }
    // A successful change is re-read from UFW so button state and rule
    // numbers always reflect the host, never optimistic local state.
    if (success) await refresh();
    return success;
  }

  /// Case-insensitive option lookup with fallback (Avalonia `Find`).
  static String find(List<String> options, String? value, String fallback) {
    for (final option in options) {
      if (option.toLowerCase() == value?.toLowerCase()) return option;
    }
    for (final option in options) {
      if (option == fallback) return option;
    }
    return options.first;
  }

  static String normalizeEndpoint(String value) =>
      value.trim().isEmpty ? 'any' : value.trim();

  /// "any"/"anywhere", a bare IP, or IP/CIDR with a family-correct prefix.
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
          part.codeUnits
              .any((code) => code < 0x30 || code > 0x39)) {
        return false;
      }
      if (int.parse(part) > 255) return false;
    }
    return true;
  }

  /// A single port 1–65535 or a "start:end" range with start <= end.
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
}
