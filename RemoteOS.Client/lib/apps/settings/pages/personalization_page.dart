import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_models.dart';
import '../../../core/theme/theme_palette_defaults.dart';
import '../../../core/theme/theme_service.dart';
import '../../../features/workspace/application/workspace_sync_coordinator.dart';
import '../dialogs/settings_dialogs.dart';
import '../models.dart';
import '../settings_controller.dart';
import '../shared/widgets.dart';

/// Personalization page. Contains wallpaper selection, theme mode
/// (light/dark/system), palette ComboBox + preview, accent input and theme
/// import/export/delete actions. Mirrors Avalonia's
/// `PersonalizationPage.axaml` / `PersonalizationPageViewModel.cs`.
class SettingsPersonalizationPage extends ConsumerStatefulWidget {
  const SettingsPersonalizationPage(
      {super.key, required this.palette, required this.accentCtrl});
  final ThemePalette palette;
  final TextEditingController accentCtrl;

  @override
  ConsumerState<SettingsPersonalizationPage> createState() =>
      _SettingsPersonalizationPageState();
}

class _SettingsPersonalizationPageState
    extends ConsumerState<SettingsPersonalizationPage> {
  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final prefs = themeState.preferences;
    final isDark = themeState.resolveBrightness(context) == Brightness.dark;
    final resolved = ThemePaletteDefaults.resolve(prefs, isDark);
    final selectedIsCustom = prefs.paletteId.startsWith('custom:');
    final paletteChoices = _uniquePaletteChoices([
      PaletteChoice(PaletteIds.remoteosBlue,
          'settings.palette.remoteos_blue'.tr(), false),
      PaletteChoice(PaletteIds.nord, 'settings.palette.nord'.tr(), false),
      PaletteChoice(
          PaletteIds.catppuccin, 'settings.palette.catppuccin'.tr(), false),
      for (final cp in prefs.customPalettes)
        PaletteChoice('custom:${cp.id}', cp.name, true),
    ]);
    final selectedChoiceId = paletteChoices.any((c) => c.id == prefs.paletteId)
        ? prefs.paletteId
        : PaletteIds.remoteosBlue;

    final wallpaperKey =
        ref.watch(workspaceSyncProvider).preferences?.wallpaperKey ??
            'builtin:bloom';

    final ctrl = ref.watch(settingsControllerProvider.notifier);
    final accentError = ref.watch(settingsControllerProvider).accentError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionHeader(
            palette: widget.palette,
            icon: Icons.palette_rounded,
            title: 'settings.theme'.tr(),
            subtitle: 'settings.theme.description'.tr()),
        const SizedBox(height: 20),
        _wallpaperSection(widget.palette, wallpaperKey, ctrl),
        const SizedBox(height: 20),
        _themeModeSection(widget.palette, themeState.kind, ctrl),
        const SizedBox(height: 20),
        _paletteSection(widget.palette, paletteChoices, selectedChoiceId,
            resolved, selectedIsCustom, ctrl),
        const SizedBox(height: 20),
        _accentSection(widget.palette, accentError),
      ],
    );
  }

  /// A duplicated persisted palette ID must not reach DropdownButton: Flutter
  /// requires exactly one menu item for its selected value.
  List<PaletteChoice> _uniquePaletteChoices(Iterable<PaletteChoice> choices) {
    final seenIds = <String>{};
    return choices
        .where((choice) => seenIds.add(choice.id))
        .toList(growable: false);
  }

  Widget _wallpaperSection(
      ThemePalette p, String wallpaperKey, SettingsController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionTitle(palette: p, title: 'settings.wallpaper'.tr()),
        const SizedBox(height: 8),
        SettingsCard(palette: p, children: [
          SettingsLabeledRow(
            palette: p,
            label: 'settings.wallpaper'.tr(),
            control: SettingsComboBox<String>(
              palette: p,
              value: wallpaperKey,
              items: [
                for (final w in wallpaperOptions())
                  DropdownMenuItem(
                      value: w.key,
                      child:
                          Text(w.name, style: const TextStyle(fontSize: 13))),
              ],
              onChanged: (v) {
                if (v == null) return;
                ref.read(workspaceSyncProvider.notifier).queuePreferences(ref
                    .read(workspaceSyncProvider)
                    .preferences!
                    .copyWith(wallpaperKey: v));
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 180),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ctrl.setImageMirrorStatus(
                        'todo: custom wallpaper file picker');
                  },
                  icon: const Icon(Icons.image_search_rounded, size: 16),
                  label: Text('settings.wallpaper.choose_image'.tr(),
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ]),
      ],
    );
  }

  Widget _themeModeSection(
      ThemePalette p, ThemeKind kind, SettingsController ctrl) {
    void setKind(ThemeKind k) {
      ref.read(themeProvider.notifier).setThemeKind(k);
      ctrl.queueTheme();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionTitle(palette: p, title: 'settings.theme'.tr()),
        const SizedBox(height: 8),
        SettingsCard(palette: p, children: [
          Row(
            children: [
              Expanded(
                  child: _ThemeModeTile(
                palette: p,
                kind: ThemeKind.light,
                icon: Icons.light_mode_outlined,
                label: 'settings.theme_mode.light'.tr(),
                selected: kind,
                onSelected: () => setKind(ThemeKind.light),
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: _ThemeModeTile(
                palette: p,
                kind: ThemeKind.dark,
                icon: Icons.dark_mode_outlined,
                label: 'settings.theme_mode.dark'.tr(),
                selected: kind,
                onSelected: () => setKind(ThemeKind.dark),
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: _ThemeModeTile(
                palette: p,
                kind: ThemeKind.system,
                icon: Icons.brightness_auto_outlined,
                label: 'settings.theme_mode.system'.tr(),
                selected: kind,
                onSelected: () => setKind(ThemeKind.system),
              )),
            ],
          ),
        ]),
      ],
    );
  }

  Widget _paletteSection(
    ThemePalette p,
    List<PaletteChoice> choices,
    String selectedId,
    Map<String, String> resolved,
    bool selectedIsCustom,
    SettingsController ctrl,
  ) {
    final themeNotifier = ref.read(themeProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionTitle(palette: p, title: 'settings.palette'.tr()),
        const SizedBox(height: 8),
        SettingsCard(palette: p, children: [
          SettingsLabeledRow(
            palette: p,
            label: 'settings.palette'.tr(),
            description: 'settings.palette.preview'.tr(),
            control: SettingsComboBox<String>(
              palette: p,
              value: selectedId,
              items: [
                for (final choice in choices)
                  DropdownMenuItem(
                      value: choice.id,
                      child: Text(
                        choice.isCustom
                            ? '${choice.name} (${"settings.palette.custom".tr()})'
                            : choice.name,
                        style: const TextStyle(fontSize: 13),
                      )),
              ],
              onChanged: (v) {
                if (v == null) return;
                themeNotifier.setPaletteId(v);
                ctrl.queueTheme();
              },
            ),
          ),
          const SizedBox(height: 12),
          _PalettePreviewStrip(palette: p, resolved: resolved),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 180),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final msg = await ctrl.importTheme();
                        if (!mounted) return;
                        showInfoSnack(context, msg,
                            onFallback: () => ctrl.setImageMirrorStatus(msg));
                      },
                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                      label: Text('settings.theme_import'.tr(),
                          style: const TextStyle(fontSize: 12)),
                    ),
                    OutlinedButton.icon(
                      onPressed: selectedIsCustom
                          ? () async {
                              final msg = await ctrl.exportTheme();
                              if (msg.isEmpty || !mounted) return;
                              showInfoSnack(context, msg,
                                  onFallback: () =>
                                      ctrl.setImageMirrorStatus(msg));
                            }
                          : null,
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: Text('settings.theme_export'.tr(),
                          style: const TextStyle(fontSize: 12)),
                    ),
                    OutlinedButton.icon(
                      onPressed: selectedIsCustom
                          ? () async {
                              final ok = await ctrl.deleteTheme((t, m) =>
                                  showConfirmDialog(context, ref, t, m));
                              if (!ok || !mounted) return;
                            }
                          : null,
                      icon: Icon(Icons.delete_outline_rounded,
                          size: 16, color: selectedIsCustom ? p.danger : null),
                      label: Text('settings.theme_delete'.tr(),
                          style: TextStyle(
                              fontSize: 12,
                              color: selectedIsCustom ? p.danger : null)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ]),
      ],
    );
  }

  Widget _accentSection(ThemePalette p, String? accentError) {
    final ctrl = ref.read(settingsControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionTitle(palette: p, title: 'settings.accent_color'.tr()),
        const SizedBox(height: 8),
        SettingsCard(palette: p, children: [
          SettingsLabeledRow(
            palette: p,
            label: 'settings.accent'.tr(),
            description: 'settings.accent.hint'.tr(),
            control: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.accentCtrl,
                        style: TextStyle(fontSize: 13, color: p.textPrimary),
                        onChanged: (v) =>
                            ctrl.applyAccentInput(v, widget.accentCtrl),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: '#RRGGBB',
                          errorText: accentError,
                          labelStyle:
                              TextStyle(fontSize: 12, color: p.textSecondary),
                          suffixIcon: IconButton(
                            tooltip: 'settings.accent.reset'.tr(),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            onPressed: () {
                              widget.accentCtrl.text = '';
                              ctrl.applyAccentInput('', widget.accentCtrl);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ]),
      ],
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({
    required this.palette,
    required this.kind,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final ThemePalette palette;
  final ThemeKind kind;
  final IconData icon;
  final String label;
  final ThemeKind selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == kind;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? palette.accentMuted : palette.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? palette.accent.withValues(alpha: 0.5)
                  : palette.borderDefault,
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 18,
                  color: isSelected ? palette.accent : palette.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? palette.accent : palette.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PalettePreviewStrip extends StatelessWidget {
  const _PalettePreviewStrip({required this.palette, required this.resolved});
  final ThemePalette palette;
  final Map<String, String> resolved;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 180),
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: parseHexColor(resolved['AppBackground']),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: palette.borderDefault),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: parseHexColor(resolved['Surface']),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: parseHexColor(resolved['BorderDefault'])),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 60,
                  height: 10,
                  decoration: BoxDecoration(
                    color: parseHexColor(resolved['Accent']),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const Spacer(),
                Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                        color: parseHexColor(resolved['Success']),
                        shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                        color: parseHexColor(resolved['Danger']),
                        shape: BoxShape.circle)),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
