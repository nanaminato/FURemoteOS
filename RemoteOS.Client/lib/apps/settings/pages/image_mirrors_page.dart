import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_service.dart';
import '../models.dart';
import '../settings_controller.dart';
import '../shared/widgets.dart';

/// Image Mirrors (Docker registry) settings page. Users can add custom
/// mirrors, pick the active mirror via a radio list and delete custom
/// entries. Matches Avalonia's `ImageMirrorsPage.axaml` layout with the
/// default "Docker Hub" entry always pre-seeded.
class SettingsImageMirrorsPage extends ConsumerStatefulWidget {
  const SettingsImageMirrorsPage({
    super.key,
    required this.palette,
    required this.nameCtrl,
    required this.endpointCtrl,
  });
  final ThemePalette palette;
  final TextEditingController nameCtrl;
  final TextEditingController endpointCtrl;

  @override
  ConsumerState<SettingsImageMirrorsPage> createState() =>
      _SettingsImageMirrorsPageState();
}

class _SettingsImageMirrorsPageState
    extends ConsumerState<SettingsImageMirrorsPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('settings.page.image_mirrors'.tr(),
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: widget.palette.textPrimary)),
              const SizedBox(height: 2),
              Text('settings.image_mirrors.description'.tr(),
                  style: TextStyle(
                      fontSize: 13,
                      color: widget.palette.textSecondary,
                      height: 1.35)),
            ],
          ),
        ),
        SettingsCard(palette: widget.palette, children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.nameCtrl,
                  style: TextStyle(
                      color: widget.palette.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'settings.image_mirrors.new_name'.tr(),
                    labelStyle: TextStyle(
                        color: widget.palette.textSecondary, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: widget.endpointCtrl,
                  style: TextStyle(
                      color: widget.palette.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'settings.image_mirrors.new_endpoint'.tr(),
                    labelStyle: TextStyle(
                        color: widget.palette.textSecondary, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: state.imageMirrorsLoading
                    ? null
                    : () => ctrl.addImageMirror(
                          widget.nameCtrl.text,
                          widget.endpointCtrl.text,
                          nameCtrl: widget.nameCtrl,
                          endpointCtrl: widget.endpointCtrl,
                        ),
                icon: const Icon(Icons.add, size: 16),
                label: Text('common.create'.tr(),
                    style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
          if (state.imageMirrorStatus.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(state.imageMirrorStatus,
                style: TextStyle(
                    color: widget.palette.textTertiary, fontSize: 12)),
          ],
        ]),
        const SizedBox(height: 16),
        SettingsSectionTitle(
            palette: widget.palette,
            title: 'settings.image_mirrors.registries'.tr()),
        const SizedBox(height: 8),
        if (state.imageMirrors.isEmpty)
          Text('settings.image_mirrors.empty'.tr(),
              style:
                  TextStyle(color: widget.palette.textTertiary, fontSize: 12))
        else
          SettingsCard(palette: widget.palette, children: [
            for (int i = 0; i < state.imageMirrors.length; i++) ...[
              if (i > 0) const SizedBox(height: 4),
              _ImageMirrorRadioRow(
                  palette: widget.palette,
                  mirror: state.imageMirrors[i],
                  groupValue: ctrl.selectedMirrorGroupValue(),
                  loading: state.imageMirrorsLoading,
                  onSelected: () =>
                      ctrl.selectImageMirror(state.imageMirrors[i]),
                  onRemove: () =>
                      ctrl.removeImageMirror(state.imageMirrors[i])),
            ],
          ]),
      ],
    );
  }
}

class _ImageMirrorRadioRow extends StatelessWidget {
  const _ImageMirrorRadioRow({
    required this.palette,
    required this.mirror,
    required this.groupValue,
    required this.loading,
    required this.onSelected,
    required this.onRemove,
  });
  final ThemePalette palette;
  final ImageMirrorUi mirror;
  final String groupValue;
  final bool loading;
  final VoidCallback onSelected;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(mirror.name,
                              style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          if (mirror.isDefault) ...[
                            const SizedBox(width: 8),
                            _Badge(
                                palette: palette,
                                background: palette.accentMuted,
                                foreground: palette.accent,
                                text: 'settings.image_mirrors.default'.tr()),
                          ],
                          if (mirror.isSelected && !mirror.isDefault) ...[
                            const SizedBox(width: 8),
                            _Badge(
                                palette: palette,
                                background: palette.successMuted,
                                foreground: palette.success,
                                text: 'settings.image_mirrors.in_use'.tr()),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(mirror.endpoint,
                          style: TextStyle(
                              color: palette.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            value: mirror.isDefault ? 'DEFAULT' : mirror.id,
            groupValue: groupValue,
            onChanged: (_) => onSelected(),
          ),
        ),
        if (!mirror.isDefault)
          IconButton(
            tooltip: 'common.delete'.tr(),
            onPressed: loading ? null : onRemove,
            icon: Icon(Icons.delete_outline_rounded,
                size: 18, color: palette.textTertiary),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.palette,
    required this.background,
    required this.foreground,
    required this.text,
  });
  final ThemePalette palette;
  final Color background;
  final Color foreground;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(
              color: foreground, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
