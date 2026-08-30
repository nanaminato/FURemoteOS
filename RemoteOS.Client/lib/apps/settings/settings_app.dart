// Settings application shell.
//
// Responsibilities (per AGENTS.md rule 3 "only layout composition"):
//   * Build the sidebar + content-pane layout.
//   * Select the page Widget based on the currently selected page index.
//   * Own the TextEditingController instances shared between the shell and
//     pages (accent input + image mirror create form) and pass them down.
//
// All business logic (persistence, clipboard, dialogs, network) lives in
// `settings_controller.dart`; UI helpers live in `shared/widgets.dart`;
// dialogs live in `dialogs/settings_dialogs.dart`; individual page
// compositions live in `pages/`.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_service.dart';
import '../../core/apps/builtin_app_activations.dart';
import 'pages/applications_page.dart';
import 'pages/default_apps_page.dart';
import 'pages/developer_page.dart';
import 'pages/image_mirrors_page.dart';
import 'pages/network_page.dart';
import 'pages/personalization_page.dart';
import 'pages/system_page.dart';
import 'pages/time_language_page.dart';
import 'settings_controller.dart';

class SettingsApp extends ConsumerStatefulWidget {
  const SettingsApp({super.key, this.activation});

  final SettingsActivation? activation;

  @override
  ConsumerState<SettingsApp> createState() => _SettingsAppState();
}

class _SettingsAppState extends ConsumerState<SettingsApp>
    with SingleTickerProviderStateMixin {
  static const _pageIds = [
    'system',
    'personalization',
    'time_language',
    'network',
    'applications',
    'image_mirrors',
    'default_apps',
    'developer',
  ];

  static const _pageIcons = [
    Icons.info_outline_rounded,
    Icons.palette_outlined,
    Icons.language_outlined,
    Icons.network_check_outlined,
    Icons.apps_outlined,
    Icons.wallpaper_outlined,
    Icons.link_outlined,
    Icons.bug_report_outlined,
  ];

  static const _pageLabelKeys = [
    'settings.page.system',
    'settings.page.personalization',
    'settings.page.time_language',
    'settings.page.network',
    'settings.page.applications',
    'settings.page.image_mirrors',
    'settings.page.default_apps',
    'settings.page.developer',
  ];

  late final TabController _tabController;
  int _selectedPage = 0;

  // Shared text controllers (owned by the shell because they outlive the
  // subpage Widgets in the tree).
  final _accentInputCtrl = TextEditingController();
  final _newMirrorName = TextEditingController();
  final _newMirrorEndpoint = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _pageIds.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _selectedPage = _tabController.index);
      }
    });
    widget.activation?.addListener(_applyActivation);
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyActivation());
    // Initialize state + theme accent sync after the first build so
    // WidgetRef is usable.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = ref.read(settingsControllerProvider.notifier);
      ctrl.bootstrap();
      final themePrefs = ref.read(themeProvider).preferences;
      _accentInputCtrl.text = themePrefs.accentOverride ?? '';
    });
  }

  @override
  void dispose() {
    widget.activation?.removeListener(_applyActivation);
    _tabController.dispose();
    _newMirrorName.dispose();
    _newMirrorEndpoint.dispose();
    _accentInputCtrl.dispose();
    super.dispose();
  }

  void _applyActivation() {
    final uri = widget.activation?.current;
    if (uri == null) return;
    final next =
        switch (uri.pathSegments.isEmpty ? null : uri.pathSegments.first) {
      'personalization' => 1,
      'apps' => 4,
      _ => _selectedPage,
    };
    if (next != _selectedPage && mounted) {
      setState(() => _selectedPage = next);
      _tabController.animateTo(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    return SizedBox.expand(
      child: ColoredBox(
        color: palette.appBackground,
        child: Row(
          children: [
            _SettingsSidebar(
              palette: palette,
              selectedIndex: _selectedPage,
              items: List.generate(_pageIds.length, (i) {
                return (
                  icon: _pageIcons[i],
                  label: _pageLabelKeys[i].tr(),
                );
              }),
              onTap: (i) {
                setState(() => _selectedPage = i);
                _tabController.animateTo(i);
              },
            ),
            VerticalDivider(
                width: 1, color: palette.borderSubtle, thickness: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: _buildPage(palette),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(ThemePalette p) {
    switch (_pageIds[_selectedPage]) {
      case 'system':
        return SettingsSystemPage(palette: p);
      case 'personalization':
        return SettingsPersonalizationPage(
            palette: p, accentCtrl: _accentInputCtrl);
      case 'time_language':
        return SettingsTimeLanguagePage(palette: p);
      case 'network':
        return SettingsNetworkPage(palette: p);
      case 'applications':
        return SettingsApplicationsPage(palette: p);
      case 'image_mirrors':
        return SettingsImageMirrorsPage(
          palette: p,
          nameCtrl: _newMirrorName,
          endpointCtrl: _newMirrorEndpoint,
        );
      case 'default_apps':
        return SettingsDefaultAppsPage(palette: p);
      case 'developer':
        return SettingsDeveloperPage(palette: p);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------

class _SettingsSidebar extends StatelessWidget {
  const _SettingsSidebar({
    required this.palette,
    required this.selectedIndex,
    required this.items,
    required this.onTap,
  });
  final ThemePalette palette;
  final int selectedIndex;
  final List<({IconData icon, String label})> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      color: palette.surface,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'settings.title'.tr(),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary),
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < items.length; i++)
            _SidebarItem(
              palette: palette,
              icon: items[i].icon,
              label: items[i].label,
              selected: selectedIndex == i,
              onTap: () => onTap(i),
            ),
          const Spacer(),
          _FooterHint(palette: palette),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.palette,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final ThemePalette palette;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? palette.accentMuted : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected
                    ? palette.accent.withValues(alpha: 0.2)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? palette.accent : palette.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: selected ? palette.accent : palette.textPrimary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterHint extends StatelessWidget {
  const _FooterHint({required this.palette});
  final ThemePalette palette;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.accentMuted,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: palette.accent.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.tips_and_updates_outlined,
                size: 18, color: palette.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'settings.sync_hint'.tr(),
                style: TextStyle(
                    fontSize: 11, color: palette.textPrimary, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
