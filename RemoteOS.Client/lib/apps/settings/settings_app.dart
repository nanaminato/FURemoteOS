import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/theme/theme_service.dart';
import '../../../core/theme/theme_models.dart';
import '../../../core/auth/auth_service.dart';

/// A fully functional Settings app with:
/// - Theme mode (Light/Dark/System)
/// - Palette selection (RemoteOS Blue / Nord / Catppuccin)
/// - Accent color override
/// - Display language
/// - System info & connection details
class SettingsApp extends ConsumerStatefulWidget {
  const SettingsApp({super.key});

  @override
  ConsumerState<SettingsApp> createState() => _SettingsAppState();
}

class _SettingsAppState extends ConsumerState<SettingsApp> with SingleTickerProviderStateMixin {
  static const _pageIds = [
    'system',
    'time_language',
    'personalization',
    'applications',
    'network',
    'developer',
  ];

  late final TabController _tabController;
  int _selectedPage = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _pageIds.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _selectedPage = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    final themeState = ref.watch(themeProvider);
    final brightness = themeState.resolveBrightness(context);
    final activePalette = themeState.resolvePalette(brightness);

    return Row(
      children: [
        _buildSidebar(palette),
        VerticalDivider(width: 1, color: palette.borderSubtle, thickness: 1),
        Expanded(
          child: Container(
            color: palette.appBackground,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: _buildPage(activePalette, palette),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar(ThemePalette palette) {
    final items = <({String id, IconData icon, String labelKey})>[
      (id: 'system', icon: Icons.info_outline_rounded, labelKey: 'settings.page.system'),
      (id: 'time_language', icon: Icons.language_outlined, labelKey: 'settings.page.time_language'),
      (id: 'personalization', icon: Icons.palette_outlined, labelKey: 'settings.theme'),
      (id: 'applications', icon: Icons.apps_outlined, labelKey: 'settings.page.applications'),
      (id: 'network', icon: Icons.network_check_outlined, labelKey: 'settings.page.network'),
      (id: 'developer', icon: Icons.bug_report_outlined, labelKey: 'settings.page.developer'),
    ];

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
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: palette.textPrimary),
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < items.length; i++)
            _buildSidebarItem(
              palette,
              icon: items[i].icon,
              label: items[i].labelKey.tr(),
              selected: _selectedPage == i,
              onTap: () {
                setState(() => _selectedPage = i);
                _tabController.animateTo(i);
              },
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.accentMuted,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: palette.accent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.tips_and_updates_outlined, size: 18, color: palette.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All preferences sync to your workspace.',
                      style: TextStyle(fontSize: 11, color: palette.textPrimary, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    ThemePalette palette, {
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
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
                color: selected ? palette.accent.withOpacity(0.2) : Colors.transparent,
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

  Widget _buildPage(ThemePalette activePalette, ThemePalette rawPalette) {
    switch (_pageIds[_selectedPage]) {
      case 'system':
        return _buildSystemPage(activePalette);
      case 'time_language':
        return _buildLanguagePage(activePalette);
      case 'personalization':
        return _buildPersonalizationPage(activePalette);
      case 'applications':
        return _buildApplicationsPage(activePalette);
      case 'network':
        return _buildNetworkPage(activePalette);
      case 'developer':
        return _buildDeveloperPage(activePalette);
      default:
        return const SizedBox.shrink();
    }
  }

  // ======= System Page =======
  Widget _buildSystemPage(ThemePalette p) {
    final auth = ref.watch(authProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(p, Icons.computer_rounded, 'settings.page.system'.tr(),
            subtitle: 'settings.system.tagline'.tr()),
        const SizedBox(height: 20),
        _card(p, [
          _infoRow(p, 'settings.version'.tr(), 'v1.0.0 (Flutter port)'),
          _infoRow(p, 'settings.connection_status'.tr(), auth.isAuthenticated ? 'Connected' : 'Disconnected',
              valueColor: auth.isAuthenticated ? p.success : p.textTertiary),
          _infoRow(p, 'settings.server'.tr(), auth.serverUrl ?? '—'),
          _infoRow(p, 'settings.username'.tr(), auth.username ?? '—'),
          _infoRow(p, 'settings.workspace'.tr(), 'Default workspace'),
        ]),
      ],
    );
  }

  // ======= Language Page =======
  Widget _buildLanguagePage(ThemePalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(p, Icons.translate_rounded, 'settings.page.time_language'.tr(),
            subtitle: 'settings.language_region.description'.tr()),
        const SizedBox(height: 20),
        _sectionTitle(p, 'settings.display_language'.tr()),
        const SizedBox(height: 8),
        _card(p, [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _languageChip(p, const Locale('en', 'US')),
              _languageChip(p, const Locale('zh', 'CN')),
              _languageChip(p, const Locale('ja', 'JP')),
            ],
          ),
        ]),
      ],
    );
  }

  Widget _languageChip(ThemePalette p, Locale locale) {
    final current = context.locale;
    final selected = current.toLanguageTag() == locale.toLanguageTag();
    final key = 'language.${locale.toLanguageTag().replaceAll('-', '_')}';
    return ChoiceChip(
      label: Text(key.tr(), style: TextStyle(fontSize: 13, color: selected ? p.textOnAccent : p.textPrimary)),
      selected: selected,
      selectedColor: p.accent,
      backgroundColor: p.surfaceRaised,
      side: BorderSide(color: selected ? p.accent : p.borderDefault),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) {
        setState(() {});
        context.setLocale(locale);
      },
    );
  }

  // ======= Personalization Page =======
  Widget _buildPersonalizationPage(ThemePalette p) {
    final themeState = ref.watch(themeProvider);
    final prefs = themeState.preferences;
    final themeNotifier = ref.read(themeProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(p, Icons.palette_rounded, 'settings.theme'.tr(),
            subtitle: 'Customize colors, modes, and look.'),
        const SizedBox(height: 20),
        // Theme mode
        _sectionTitle(p, 'settings.theme'.tr()),
        const SizedBox(height: 8),
        _card(p, [
          Row(
            children: [
              Expanded(
                child: _themeModeTile(p, ThemeKind.light, Icons.light_mode_outlined, 'settings.theme_mode.light'.tr(), themeState.kind, themeNotifier),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _themeModeTile(p, ThemeKind.dark, Icons.dark_mode_outlined, 'settings.theme_mode.dark'.tr(), themeState.kind, themeNotifier),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _themeModeTile(p, ThemeKind.system, Icons.brightness_auto_outlined, 'settings.theme_mode.system'.tr(), themeState.kind, themeNotifier),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 20),
        // Palette
        _sectionTitle(p, 'Color Palette'),
        const SizedBox(height: 8),
        _card(p, [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _paletteTile(p, PaletteIds.remoteosBlue, 'settings.palette.remoteos_blue'.tr(), prefs.paletteId, themeNotifier),
              _paletteTile(p, PaletteIds.nord, 'settings.palette.nord'.tr(), prefs.paletteId, themeNotifier),
              _paletteTile(p, PaletteIds.catppuccin, 'settings.palette.catppuccin'.tr(), prefs.paletteId, themeNotifier),
            ],
          ),
        ]),
        const SizedBox(height: 20),
        // Accent color
        _sectionTitle(p, 'settings.accent_color'.tr()),
        const SizedBox(height: 8),
        _card(p, [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _accentOption(p, '#0078D4', prefs.accentOverride, themeNotifier),
              _accentOption(p, '#8B5CF6', prefs.accentOverride, themeNotifier),
              _accentOption(p, '#EC4899', prefs.accentOverride, themeNotifier),
              _accentOption(p, '#10B981', prefs.accentOverride, themeNotifier),
              _accentOption(p, '#F59E0B', prefs.accentOverride, themeNotifier),
              _accentOption(p, '#EF4444', prefs.accentOverride, themeNotifier),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => themeNotifier.setAccentOverride(null),
                icon: Icon(Icons.refresh_rounded, size: 16, color: p.textSecondary),
                label: Text('Reset', style: TextStyle(fontSize: 12, color: p.textSecondary)),
              ),
            ],
          ),
        ]),
      ],
    );
  }

  Widget _themeModeTile(
    ThemePalette p,
    ThemeKind kind,
    IconData icon,
    String label,
    ThemeKind selected,
    ThemeNotifier notifier,
  ) {
    final isSelected = selected == kind;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => notifier.setThemeKind(kind),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? p.accentMuted : p.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? p.accent.withOpacity(0.5) : p.borderDefault,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: isSelected ? p.accent : p.textSecondary),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? p.accent : p.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paletteTile(
    ThemePalette p,
    String paletteId,
    String name,
    String currentId,
    ThemeNotifier notifier,
  ) {
    final selected = paletteId == currentId;
    final sample = ThemePaletteDefaults.resolve(
      ThemePreferencesDto(paletteId: paletteId),
      false,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => notifier.setPaletteId(paletteId),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? p.accent : p.borderDefault,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Color(int.parse(('FF' + sample['ShellBackground']!.replaceFirst('#', '')), radix: 16)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Color(int.parse(('FF' + sample['Surface']!.replaceFirst('#', '')), radix: 16)),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Color(int.parse(('FF' + sample['BorderDefault']!.replaceFirst('#', '')), radix: 16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 52,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Color(int.parse(('FF' + sample['Accent']!.replaceFirst('#', '')), radix: 16)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Color(int.parse(('FF' + sample['Accent']!.replaceFirst('#', '')), radix: 16)),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 12,
                        color: p.textPrimary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle_rounded, size: 16, color: p.accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accentOption(ThemePalette p, String hex, String? current, ThemeNotifier notifier) {
    final selected = current != null && current.toUpperCase() == hex.toUpperCase();
    final color = Color(int.parse(('FF' + hex.replaceFirst('#', '')), radix: 16));
    return Tooltip(
      message: hex,
      child: GestureDetector(
        onTap: () => notifier.setAccentOverride(hex),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: selected ? p.textPrimary : p.borderDefault,
              width: selected ? 3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: selected
              ? Icon(Icons.check_rounded, color: ThemePaletteDefaults.bestForeground(hex) == '#FFFFFF' ? Colors.white : Colors.black, size: 20)
              : null,
        ),
      ),
    );
  }

  // ======= Applications Page =======
  Widget _buildApplicationsPage(ThemePalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(p, Icons.apps_rounded, 'settings.page.applications'.tr(),
            subtitle: 'Manage installed applications and permissions.'),
        const SizedBox(height: 20),
        _card(p, [
          for (final id in ['welcome', 'notepad', 'code_editor', 'terminal', 'explorer', 'browser', 'settings'])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: p.accentMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_iconFor(id), size: 20, color: p.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('app.$id'.tr(), style: TextStyle(color: p.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Built-in RemoteOS application', style: TextStyle(color: p.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.textSecondary,
                      minimumSize: const Size(72, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: const Text('Manage'),
                  ),
                ],
              ),
            ),
        ]),
      ],
    );
  }

  IconData _iconFor(String id) => switch (id) {
        'welcome' => Icons.waving_hand_outlined,
        'notepad' => Icons.edit_note_outlined,
        'code_editor' => Icons.code_outlined,
        'terminal' => Icons.terminal_outlined,
        'explorer' => Icons.folder_outlined,
        'browser' => Icons.public_outlined,
        'settings' => Icons.settings_outlined,
        _ => Icons.widgets_outlined,
      };

  // ======= Network Page =======
  Widget _buildNetworkPage(ThemePalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(p, Icons.network_check_rounded, 'settings.page.network'.tr(),
            subtitle: 'Connection quality, mirrors, and diagnostics.'),
        const SizedBox(height: 20),
        _card(p, [
          _infoRow(p, 'Latency (simulated)', '23 ms'),
          _infoRow(p, 'Transport', 'HTTP/1.1 + SignalR WebSockets'),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.speed_rounded, size: 16),
                  label: Text('settings.test_connection'.tr()),
                ),
              ),
            ],
          ),
        ]),
      ],
    );
  }

  // ======= Developer Page =======
  Widget _buildDeveloperPage(ThemePalette p) {
    final devMode = false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(p, Icons.developer_mode_rounded, 'settings.page.developer'.tr(),
            subtitle: 'settings.developer_mode.description'.tr()),
        const SizedBox(height: 20),
        _card(p, [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('settings.developer_mode'.tr(), style: TextStyle(color: p.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Install sideloaded packages and debug via local bridge.', style: TextStyle(color: p.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Switch(value: devMode, onChanged: (_) {}),
            ],
          ),
        ]),
      ],
    );
  }

  // ======= Shared UI helpers =======
  Widget _sectionHeader(ThemePalette p, IconData icon, String title, {String? subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: p.accentMuted,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 22, color: p.accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.textPrimary)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 13, color: p.textSecondary, height: 1.35)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(ThemePalette p, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        title,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.textSecondary),
      ),
    );
  }

  Widget _card(ThemePalette p, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: p.borderSubtle, thickness: 1),
              ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(ThemePalette p, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        SizedBox(
          width: 180,
          child: Text(label, style: TextStyle(color: p.textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: valueColor ?? p.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
