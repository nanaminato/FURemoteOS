// Firewall main View (ARCHITECTURE.md § 8).
//
// Owns layout, focus, theme lookup and dialog integration; delegates
// business logic to [FirewallViewModel].
//
// This mirrors DockerView conventions: ConsumerStatefulWidget owns View
// hooks (password request, rule editor open), theme palette is resolved via
// [watchPalette], toolbar uses Material's InkWell rather than a non-existent
// RemoteToolbar widget, and commands are invoked via [Command.run]/[canRun]
// without the non-existent CommandBuilder.

import 'package:command_it/command_it.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependency_injection.dart' as app_di;
import '../../../core/theme/theme_service.dart';
import '../../../core/window_manager/modal_manager.dart';
import '../../../core/window_manager/window_manager.dart';
import '../application/firewall_view_model.dart';
import '../domain/firewall_repository.dart';
import '../domain/firewall_ui_state.dart';
import 'components/firewall_components.dart';
import 'dialogs/firewall_dialogs.dart';

class FirewallView extends ConsumerStatefulWidget {
  const FirewallView({super.key, this.vm});

  /// Optional injected VM (tests or legacy callers may supply one).
  final FirewallViewModel? vm;

  @override
  ConsumerState<FirewallView> createState() => _FirewallViewState();
}

class _FirewallViewState extends ConsumerState<FirewallView> {
  late final FirewallViewModel _vm;

  String get _ownerId => RemoteWindowScope.of(context).window.id;

  @override
  void initState() {
    super.initState();
    _vm = widget.vm ?? app_di.di<FirewallViewModel>();
    _installHooks();
    // ignore: discarded_futures
    _vm.startCommand();
  }

  @override
  void dispose() {
    _vm.requestPassword = _noopRequestPassword;
    _vm.showRuleEditor = _noopShowRuleEditor;
    // If caller injected a VM the caller owns disposal.
    if (widget.vm == null) _vm.dispose();
    super.dispose();
  }

  void _installHooks() {
    _vm.requestPassword = _requestPassword;
    _vm.showRuleEditor = _showRuleEditor;
  }

  Future<String?> _requestPassword() async {
    final result = await ref.read(modalManagerProvider).open<String>(
          ownerId: _ownerId,
          spec: ModalSpec(
            title: 'firewall.password_dialog.title'.tr(),
            icon: Icons.password_outlined,
            preferredSize: const Size(420, 180),
            child: const FirewallPasswordDialog(),
          ),
        );
    if (result is String && result.isNotEmpty) return result;
    return null;
  }

  Future<bool> _showRuleEditor(bool editing) async {
    final result = await ref.read(modalManagerProvider).open<bool>(
          ownerId: _ownerId,
          spec: ModalSpec(
            title: (editing
                    ? 'firewall.rule.edit_dialog_title'
                    : 'firewall.rule.add_dialog_title')
                .tr(),
            icon: Icons.rule_outlined,
            preferredSize: const Size(460, 560),
            child: FirewallRuleEditorDialog(vm: _vm, editing: editing),
          ),
        );
    return result == true;
  }

  // ---- Fallback no-op callbacks, used after disposal ----

  static Future<String?> _noopRequestPassword() async => null;
  static Future<bool> _noopShowRuleEditor(bool _) async => false;

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    return ValueListenableBuilder(
      valueListenable: _vm.state,
      builder: (context, _, __) => _buildContent(context, palette),
    );
  }

  Widget _buildContent(BuildContext context, ThemePalette palette) {
    final vm = _vm;
    final s = vm.state.value;
    return Column(
      children: [
        _buildToolbar(context, vm, palette),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: s.isLoading && s.rules.isEmpty
              ? Center(child: Text('firewall.status.loading'.tr()))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusBar(context, s, palette),
                      const SizedBox(height: 12),
                      _buildDefaultsCard(context, vm, s, palette),
                      const SizedBox(height: 16),
                      _buildRulesCard(context, vm, s, palette),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // ---- Toolbar ----

  Widget _buildToolbar(
    BuildContext context,
    FirewallViewModel vm,
    ThemePalette palette,
  ) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        border: Border(bottom: BorderSide(color: palette.borderSubtle)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _ToolbarButton(
              icon: Icons.refresh,
              label: 'common.refresh'.tr(),
              palette: palette,
              enabled: vm.canRefresh(),
              command: vm.refreshCommand,
            ),
            const SizedBox(width: 8),
            _ToolbarButton(
              icon: Icons.toggle_on,
              label: 'firewall.enable'.tr(),
              palette: palette,
              enabled: vm.canEnable(),
              command: vm.enableCommand,
            ),
            const SizedBox(width: 8),
            _ToolbarButton(
              icon: Icons.toggle_off,
              label: 'firewall.disable'.tr(),
              palette: palette,
              enabled: vm.canDisable(),
              command: vm.disableCommand,
            ),
            _ToolbarSeparator(palette: palette),
            _ToolbarButton(
              icon: Icons.save,
              label: 'firewall.save_defaults'.tr(),
              palette: palette,
              enabled: vm.canManageAction(),
              command: vm.saveDefaultsCommand,
            ),
            const SizedBox(width: 8),
            _ToolbarButton(
              icon: Icons.add,
              label: 'firewall.rule.add'.tr(),
              palette: palette,
              enabled: vm.canManageAction(),
              command: vm.addRuleCommand,
            ),
            const SizedBox(width: 8),
            _ToolbarButton(
              icon: Icons.edit,
              label: 'firewall.rule.update'.tr(),
              palette: palette,
              enabled: vm.canEditRule(),
              command: vm.updateRuleCommand,
            ),
            const SizedBox(width: 8),
            _ToolbarButton(
              icon: Icons.delete_outline,
              label: 'firewall.rule.delete'.tr(),
              palette: palette,
              enabled: vm.canEditRule(),
              command: vm.deleteRuleCommand,
            ),
          ],
        ),
      ),
    );
  }

  // ---- Status card ----

  Widget _buildStatusBar(
    BuildContext context,
    FirewallUiState s,
    ThemePalette palette,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.borderDefault),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: s.isEnabled ? palette.success : palette.warning,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.statusText,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Default policies card ----

  Widget _buildDefaultsCard(
    BuildContext context,
    FirewallViewModel vm,
    FirewallUiState s,
    ThemePalette palette,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'firewall.rule.editor_title'.tr(),
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              FirewallChoiceField(
                label: 'firewall.default_incoming'.tr(),
                value: s.incomingPolicy,
                choices: FirewallRepository.policies,
                width: 220,
                onChanged: (value) {
                  if (value != null) vm.setIncomingPolicy(value);
                },
              ),
              FirewallChoiceField(
                label: 'firewall.default_outgoing'.tr(),
                value: s.outgoingPolicy,
                choices: FirewallRepository.policies,
                width: 220,
                onChanged: (value) {
                  if (value != null) vm.setOutgoingPolicy(value);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Rules card ----

  Widget _buildRulesCard(
    BuildContext context,
    FirewallViewModel vm,
    FirewallUiState s,
    ThemePalette palette,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 260),
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Text(
              'firewall.rule.editor_title'.tr(),
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: s.rules.isEmpty
                ? SizedBox(
                    height: 120,
                    child: Center(
                      child: Text(
                        'firewall.status.ready'.tr(),
                        style: TextStyle(color: palette.textSecondary),
                      ),
                    ),
                  )
                : FirewallRuleTable(
                    rules: s.rules,
                    selectedRule: s.selectedRule,
                    onSelectRule: vm.selectRule,
                  ),
          ),
        ],
      ),
    );
  }
}

// ---- Reusable toolbar building blocks (defined here because the
// project-wide core/window_manager/toolbar_widgets.dart does not currently
// exist; keeping these local to the firewall feature avoids inventing a
// shared API mid-migration. See AGENTS.md § 6 (smallest coherent change).

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.palette,
    required this.enabled,
    required this.command,
  });

  final IconData icon;
  final String label;
  final ThemePalette palette;
  final bool enabled;
  final Command command;

  @override
  Widget build(BuildContext context) {
    final onPressed = enabled && command.canRun.value ? () => command() : null;
    final fg = onPressed != null ? palette.textPrimary : palette.textDisabled;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarSeparator extends StatelessWidget {
  const _ToolbarSeparator({required this.palette});

  final ThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: palette.borderSubtle,
    );
  }
}
