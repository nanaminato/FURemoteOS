// Firewall dialogs (ARCHITECTURE.md § 17 — owned by the View layer because
// they mount Flutter widgets).  Results are routed back through the caller
// via ModalManager so the ViewModel never sees BuildContext.
//
// * [FirewallPasswordDialog]: one-shot password confirmation for
//   non-root users.  Mirrors Avalonia `RequestPasswordAsync`.
// * [FirewallRuleEditorDialog]: add + edit rule modal (460×560).  Mirrors
//   Avalonia `ShowRuleEditorAsync`.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_service.dart';
import '../../../../core/window_manager/modal_manager.dart';
import '../../../../core/window_manager/window_manager.dart';
import '../../application/firewall_view_model.dart';
import '../components/firewall_components.dart';

/// One-shot password collection dialog.  The caller receives the user input
/// via ModalManager; a non-null non-empty String is returned when the user
/// presses OK.
class FirewallPasswordDialog extends ConsumerStatefulWidget {
  const FirewallPasswordDialog({super.key});

  @override
  ConsumerState<FirewallPasswordDialog> createState() =>
      _FirewallPasswordDialogState();
}

class _FirewallPasswordDialogState
    extends ConsumerState<FirewallPasswordDialog> {
  final password = TextEditingController();

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dialogId = RemoteWindowScope.of(context).window.id;
    final modal = ref.read(modalManagerProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'firewall.password_dialog.message'.tr(),
            style: TextStyle(color: palette.textPrimary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: true,
            autofocus: true,
            onSubmitted: (_) => modal.complete<String>(dialogId, password.text),
            decoration: InputDecoration(
              hintText: 'firewall.password_placeholder'.tr(),
              isDense: true,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => modal.dismiss(dialogId),
                child: Text('common.cancel'.tr()),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () =>
                    modal.complete<String>(dialogId, password.text),
                child: Text('common.ok'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Add / edit firewall rule editor.  Reads initial editor state from the
/// ViewModel's selected rule (when editing) and commits via
/// [FirewallViewModel.commitAdd] / [commitUpdate].
class FirewallRuleEditorDialog extends ConsumerStatefulWidget {
  const FirewallRuleEditorDialog({
    super.key,
    required this.vm,
    required this.editing,
  });

  final FirewallViewModel vm;
  final bool editing;

  @override
  ConsumerState<FirewallRuleEditorDialog> createState() =>
      _FirewallRuleEditorDialogState();
}

class _FirewallRuleEditorDialogState
    extends ConsumerState<FirewallRuleEditorDialog> {
  late String action;
  late String direction;
  late String protocol;
  late final source = TextEditingController();
  late final destination = TextEditingController();
  late final port = TextEditingController();

  static String _editable(String? value) =>
      value == null || value == 'any' ? '' : value;

  @override
  void initState() {
    super.initState();
    final selected = widget.vm.selectedRule;
    action = widget.editing
        ? FirewallViewModel.find(widget.vm.actions, selected?.action, 'allow')
        : 'allow';
    direction = widget.editing
        ? FirewallViewModel.find(
            widget.vm.directions, selected?.direction, 'in')
        : 'in';
    protocol = widget.editing
        ? FirewallViewModel.find(widget.vm.protocols, selected?.protocol, 'tcp')
        : 'tcp';
    source.text = widget.editing ? _editable(selected?.source) : '';
    destination.text = widget.editing ? _editable(selected?.destination) : '';
    port.text = widget.editing ? _editable(selected?.port) : '';
  }

  @override
  void dispose() {
    source.dispose();
    destination.dispose();
    port.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = widget.editing
        ? await widget.vm.commitUpdate(
            action: action,
            direction: direction,
            protocol: protocol,
            source: source.text,
            destination: destination.text,
            port: port.text,
          )
        : await widget.vm.commitAdd(
            action: action,
            direction: direction,
            protocol: protocol,
            source: source.text,
            destination: destination.text,
            port: port.text,
          );
    if (ok && mounted) {
      final dialogId = RemoteWindowScope.of(context).window.id;
      ref.read(modalManagerProvider).complete<bool>(dialogId, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dialogId = RemoteWindowScope.of(context).window.id;
    final modal = ref.read(modalManagerProvider);
    return ListenableBuilder(
      listenable: widget.vm.state,
      builder: (context, _) {
        final loading = widget.vm.state.value.isLoading;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'firewall.rule.help'.tr(),
                style: TextStyle(fontSize: 12, color: palette.textTertiary),
              ),
              const SizedBox(height: 12),
              Text(
                widget.vm.state.value.statusText,
                style: TextStyle(color: palette.textPrimary),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FirewallChoiceField(
                        label: 'firewall.rule.action'.tr(),
                        value: action,
                        choices: widget.vm.actions,
                        width: 360,
                        onChanged: (value) =>
                            setState(() => action = value ?? 'allow'),
                      ),
                      const SizedBox(height: 12),
                      FirewallChoiceField(
                        label: 'firewall.rule.direction'.tr(),
                        value: direction,
                        choices: widget.vm.directions,
                        width: 360,
                        onChanged: (value) =>
                            setState(() => direction = value ?? 'in'),
                      ),
                      const SizedBox(height: 12),
                      FirewallChoiceField(
                        label: 'firewall.rule.protocol'.tr(),
                        value: protocol,
                        choices: widget.vm.protocols,
                        width: 360,
                        onChanged: (value) =>
                            setState(() => protocol = value ?? 'tcp'),
                      ),
                      const SizedBox(height: 12),
                      Tooltip(
                        message: 'firewall.rule.source_tooltip'.tr(),
                        child: TextField(
                          controller: source,
                          decoration: InputDecoration(
                            labelText: 'firewall.rule.source'.tr(),
                            hintText: 'firewall.rule.source_hint'.tr(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Tooltip(
                        message: 'firewall.rule.destination_tooltip'.tr(),
                        child: TextField(
                          controller: destination,
                          decoration: InputDecoration(
                            labelText: 'firewall.rule.destination'.tr(),
                            hintText: 'firewall.rule.destination_hint'.tr(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: port,
                        decoration: InputDecoration(
                          labelText: 'firewall.rule.port'.tr(),
                          hintText: 'firewall.rule.port_hint'.tr(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => modal.dismiss(dialogId),
                    child: Text('common.cancel'.tr()),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: loading ? null : _submit,
                    child: Text(
                      widget.editing
                          ? 'firewall.rule.update'.tr()
                          : 'firewall.rule.add'.tr(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
