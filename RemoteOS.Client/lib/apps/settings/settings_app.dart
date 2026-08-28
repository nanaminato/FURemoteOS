import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/theme/theme_service.dart';
import '../../../core/theme/theme_models.dart';
import '../../../core/theme/theme_palette_defaults.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/localization/language_catalog.dart';
import '../../../features/workspace/application/workspace_sync_coordinator.dart';
import '../../../features/workspace/domain/workspace_models.dart';

/// Local UI model: an application option for protocol / extension mapping.
class _AppOptionUi {
  const _AppOptionUi({
    required this.id,
    required this.displayName,
    required this.schemes,
    required this.extensions,
  });
  final String id;
  final String displayName;
  final List<String> schemes;
  final List<String> extensions;
}

/// Local UI model: one protocol/extension → app mapping row.
class _DefaultAppMappingUi {
  _DefaultAppMappingUi({
    required this.scheme,
    required this.appId,
  });
  String scheme;
  String appId;
}

/// Local UI model: one image mirror registry entry.
class _ImageMirrorUi {
  _ImageMirrorUi({
    required this.id,
    required this.name,
    required this.endpoint,
    required this.isDefault,
    required this.isSelected,
  });
  String id;
  String name;
  String endpoint;
  bool isDefault;
  bool isSelected;
}

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

  late final TabController _tabController;
  int _selectedPage = 0;

  // Default apps local UI state (persisted via WorkspacePreferences.defaultApps).
  final List<_DefaultAppMappingUi> _defaultMappings = [];
  final List<_AppOptionUi> _appOptions = const [
    _AppOptionUi(id: 'remoteos.welcome', displayName: '欢迎 / Welcome', schemes: [], extensions: []),
    _AppOptionUi(id: 'remoteos.notepad', displayName: '记事本 / Notepad', schemes: ['txt', 'md'], extensions: ['.txt', '.md', '.markdown', '.json', '.xml', '.yaml', '.yml', '.toml', '.ini', '.cfg', '.conf', '.config', '.log']),
    _AppOptionUi(id: 'remoteos.code_editor', displayName: '代码编辑器 / Code Editor', schemes: [], extensions: ['.dart', '.cs', '.py', '.ts', '.tsx', '.js', '.jsx', '.java', '.go', '.rs', '.c', '.cpp', '.h', '.hpp', '.sh', '.ps1', '.bat', '.sql', '.kt', '.swift']),
    _AppOptionUi(id: 'remoteos.terminal', displayName: '终端 / Terminal', schemes: [], extensions: ['.sh', '.ps1', '.bat', '.cmd']),
    _AppOptionUi(id: 'remoteos.explorer', displayName: '文件资源管理器 / Explorer', schemes: ['file'], extensions: []),
    _AppOptionUi(id: 'remoteos.browser', displayName: '浏览器 / Browser', schemes: ['http', 'https', 'mailto', 'ftp'], extensions: ['.html', '.htm', '.xhtml', '.mht']),
    _AppOptionUi(id: 'remoteos.settings', displayName: '设置 / Settings', schemes: ['remoteos'], extensions: []),
    _AppOptionUi(id: 'remoteos.docker_manager', displayName: 'Docker 管理器 / Docker Manager', schemes: [], extensions: ['.dockerfile', '.yaml', '.yml']),
  ];
  final List<String> _availableSchemes = [
    'http', 'https', 'mailto', 'ftp', 'file', 'remoteos',
    '.txt', '.md', '.markdown', '.json', '.xml', '.yaml', '.yml', '.toml',
    '.ini', '.cfg', '.conf', '.config', '.log', '.csv',
    '.html', '.htm', '.xhtml',
    '.dart', '.cs', '.py', '.ts', '.tsx', '.js', '.jsx',
    '.java', '.go', '.rs', '.c', '.cpp', '.h',
    '.sh', '.ps1', '.bat', '.cmd', '.sql', '.kt', '.swift',
    '.dockerfile', '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp', '.svg',
  ];

  // Image mirrors local UI state.
  final List<_ImageMirrorUi> _imageMirrors = [
    _ImageMirrorUi(id: '', name: 'Docker Hub (默认 / Default)', endpoint: 'registry-1.docker.io', isDefault: true, isSelected: false),
  ];
  final _newMirrorName = TextEditingController();
  final _newMirrorEndpoint = TextEditingController();
  String _imageMirrorStatus = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _pageIds.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _selectedPage = _tabController.index);
      }
    });
    _loadDefaultAppMappings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _newMirrorName.dispose();
    _newMirrorEndpoint.dispose();
    super.dispose();
  }

  void _loadDefaultAppMappings() {
    final prefs = ref.read(workspaceSyncProvider).preferences;
    if (prefs == null) return;
    for (final m in prefs.defaultApps) {
      _defaultMappings.add(_DefaultAppMappingUi(
        scheme: m.scheme,
        appId: m.appId,
      ));
    }
  }

  void _persistDefaultApps() {
    final current = ref.read(workspaceSyncProvider).preferences;
    if (current == null) return;
    final updated = current.copyWith(
      defaultApps: _defaultMappings
          .map((m) => WorkspaceDefaultAppMapping(scheme: m.scheme, appId: m.appId))
          .toList(growable: false),
    );
    ref.read(workspaceSyncProvider.notifier).queuePreferences(updated);
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
      (
        id: 'system',
        icon: Icons.info_outline_rounded,
        labelKey: 'settings.page.system'
      ),
      (
        id: 'personalization',
        icon: Icons.palette_outlined,
        labelKey: 'settings.page.personalization'
      ),
      (
        id: 'time_language',
        icon: Icons.language_outlined,
        labelKey: 'settings.page.time_language'
      ),
      (
        id: 'network',
        icon: Icons.network_check_outlined,
        labelKey: 'settings.page.network'
      ),
      (
        id: 'applications',
        icon: Icons.apps_outlined,
        labelKey: 'settings.page.applications'
      ),
      (
        id: 'image_mirrors',
        icon: Icons.wallpaper_outlined,
        labelKey: 'settings.page.image_mirrors'
      ),
      (
        id: 'default_apps',
        icon: Icons.link_outlined,
        labelKey: 'settings.page.default_apps'
      ),
      (
        id: 'developer',
        icon: Icons.bug_report_outlined,
        labelKey: 'settings.page.developer'
      ),
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
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary),
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
                  Icon(Icons.tips_and_updates_outlined,
                      size: 18, color: palette.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All preferences sync to your workspace.',
                      style: TextStyle(
                          fontSize: 11,
                          color: palette.textPrimary,
                          height: 1.3),
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
                color: selected
                    ? palette.accent.withOpacity(0.2)
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

  Widget _buildPage(ThemePalette activePalette, ThemePalette rawPalette) {
    switch (_pageIds[_selectedPage]) {
      case 'system':
        return _buildSystemPage(activePalette);
      case 'personalization':
        return _buildPersonalizationPage(activePalette);
      case 'time_language':
        return _buildLanguagePage(activePalette);
      case 'network':
        return _buildNetworkPage(activePalette);
      case 'applications':
        return _buildApplicationsPage(activePalette);
      case 'image_mirrors':
        return _buildImageMirrorsPage(activePalette);
      case 'default_apps':
        return _buildDefaultAppsPage(activePalette);
      case 'developer':
        return _buildDeveloperPage(activePalette);
      default:
        return const SizedBox.shrink();
    }
  }

  // ======= System Page =======
  Widget _buildSystemPage(ThemePalette p) {
    final auth = ref.watch(authProvider);
    final hostPlatform = Platform.operatingSystem;
    final deviceName = Platform.localHostname;
    final connected = auth.isAuthenticated;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('settings.page.system'.tr(),
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary)),
              const SizedBox(height: 2),
              Text('settings.system.tagline'.tr(),
                  style: TextStyle(
                      fontSize: 13,
                      color: p.textSecondary,
                      height: 1.35)),
            ],
          ),
        ),
        _card(p, [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('settings.about'.tr(),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.textSecondary)),
          ),
          _infoRow(p, 'settings.version'.tr(), 'RemoteOS 0.1'),
          _infoRow(p, 'settings.connection_status'.tr(),
              connected
                  ? 'settings.value.connected'.tr()
                  : 'settings.value.not_connected'.tr(),
              valueColor: connected ? p.success : p.textTertiary),
          _infoRow(p, 'settings.server'.tr(), auth.serverUrl ?? '—'),
        ]),
        const SizedBox(height: 16),
        _card(p, [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('settings.account_workspace'.tr(),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.textSecondary)),
          ),
          _infoRow(p, 'settings.username'.tr(), auth.username ?? '—'),
          _infoRow(p, 'settings.host_platform'.tr(), hostPlatform),
          _infoRow(p, 'settings.workspace'.tr(),
              '${auth.workspaceName ?? '—'} Workspace'),
          _infoRow(p, 'settings.device'.tr(), deviceName),
          _infoRow(p, 'settings.device_role'.tr(), 'Controller'),
          _infoRow(p, 'settings.last_login'.tr(), '2026-08-28 08:39'),
        ]),
        const SizedBox(height: 16),
        Text('settings.system.description'.tr(),
            style: TextStyle(
                fontSize: 12, color: p.textSecondary.withOpacity(0.75))),
      ],
    );
  }

  // ======= Language Page =======
  Widget _buildLanguagePage(ThemePalette p) {
    final languages = ref.watch(languageCatalogProvider).languages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
            p, Icons.translate_rounded, 'settings.page.time_language'.tr(),
            subtitle: 'settings.language_region.description'.tr()),
        const SizedBox(height: 20),
        _sectionTitle(p, 'settings.display_language'.tr()),
        const SizedBox(height: 8),
        _card(p, [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final language in languages) _languageChip(p, language),
            ],
          ),
        ]),
      ],
    );
  }

  Widget _languageChip(ThemePalette p, LanguageOption language) {
    final locale = language.locale;
    final current = context.locale;
    final selected = current.toLanguageTag() == locale.toLanguageTag();
    return ChoiceChip(
      label: Text(language.displayName,
          style: TextStyle(
              fontSize: 13, color: selected ? p.textOnAccent : p.textPrimary)),
      selected: selected,
      selectedColor: p.accent,
      backgroundColor: p.surfaceRaised,
      side: BorderSide(color: selected ? p.accent : p.borderDefault),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) {
        setState(() {});
        context.setLocale(locale);
        final current = ref.read(workspaceSyncProvider).preferences;
        if (current != null) {
          ref
              .read(workspaceSyncProvider.notifier)
              .queuePreferences(current.copyWith(language: language.localeTag));
        }
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
                child: _themeModeTile(
                    p,
                    ThemeKind.light,
                    Icons.light_mode_outlined,
                    'settings.theme_mode.light'.tr(),
                    themeState.kind,
                    () => _setThemeKind(ThemeKind.light)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _themeModeTile(
                    p,
                    ThemeKind.dark,
                    Icons.dark_mode_outlined,
                    'settings.theme_mode.dark'.tr(),
                    themeState.kind,
                    () => _setThemeKind(ThemeKind.dark)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _themeModeTile(
                    p,
                    ThemeKind.system,
                    Icons.brightness_auto_outlined,
                    'settings.theme_mode.system'.tr(),
                    themeState.kind,
                    () => _setThemeKind(ThemeKind.system)),
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
              _paletteTile(
                  p,
                  PaletteIds.remoteosBlue,
                  'settings.palette.remoteos_blue'.tr(),
                  prefs.paletteId,
                  () => _setPalette(PaletteIds.remoteosBlue)),
              _paletteTile(p, PaletteIds.nord, 'settings.palette.nord'.tr(),
                  prefs.paletteId, () => _setPalette(PaletteIds.nord)),
              _paletteTile(
                  p,
                  PaletteIds.catppuccin,
                  'settings.palette.catppuccin'.tr(),
                  prefs.paletteId,
                  () => _setPalette(PaletteIds.catppuccin)),
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
              _accentOption(p, '#0078D4', prefs.accentOverride,
                  () => _setAccent('#0078D4')),
              _accentOption(p, '#8B5CF6', prefs.accentOverride,
                  () => _setAccent('#8B5CF6')),
              _accentOption(p, '#EC4899', prefs.accentOverride,
                  () => _setAccent('#EC4899')),
              _accentOption(p, '#10B981', prefs.accentOverride,
                  () => _setAccent('#10B981')),
              _accentOption(p, '#F59E0B', prefs.accentOverride,
                  () => _setAccent('#F59E0B')),
              _accentOption(p, '#EF4444', prefs.accentOverride,
                  () => _setAccent('#EF4444')),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _setAccent(null),
                icon: Icon(Icons.refresh_rounded,
                    size: 16, color: p.textSecondary),
                label: Text('Reset',
                    style: TextStyle(fontSize: 12, color: p.textSecondary)),
              ),
            ],
          ),
        ]),
      ],
    );
  }

  void _setThemeKind(ThemeKind kind) {
    ref.read(themeProvider.notifier).setThemeKind(kind);
    _queueTheme();
  }

  void _setPalette(String paletteId) {
    ref.read(themeProvider.notifier).setPaletteId(paletteId);
    _queueTheme();
  }

  void _setAccent(String? accent) {
    ref.read(themeProvider.notifier).setAccentOverride(accent);
    _queueTheme();
  }

  void _queueTheme() {
    final current = ref.read(themeProvider);
    ref
        .read(workspaceSyncProvider.notifier)
        .queueTheme(current.kind, current.preferences);
  }

  Widget _themeModeTile(
    ThemePalette p,
    ThemeKind kind,
    IconData icon,
    String label,
    ThemeKind selected,
    VoidCallback onSelected,
  ) {
    final isSelected = selected == kind;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelected,
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
              Icon(icon,
                  size: 18, color: isSelected ? p.accent : p.textSecondary),
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
    VoidCallback onSelected,
  ) {
    final selected = paletteId == currentId;
    final sample = ThemePaletteDefaults.resolve(
      ThemePreferencesDto(paletteId: paletteId),
      false,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelected,
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
                  color: Color(int.parse(
                      ('FF' + sample['ShellBackground']!.replaceFirst('#', '')),
                      radix: 16)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Color(int.parse(
                            ('FF' + sample['Surface']!.replaceFirst('#', '')),
                            radix: 16)),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Color(int.parse(
                              ('FF' +
                                  sample['BorderDefault']!
                                      .replaceFirst('#', '')),
                              radix: 16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 52,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Color(int.parse(
                            ('FF' + sample['Accent']!.replaceFirst('#', '')),
                            radix: 16)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Color(int.parse(
                            ('FF' + sample['Accent']!.replaceFirst('#', '')),
                            radix: 16)),
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
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
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

  Widget _accentOption(
      ThemePalette p, String hex, String? current, VoidCallback onSelected) {
    final selected =
        current != null && current.toUpperCase() == hex.toUpperCase();
    final color =
        Color(int.parse(('FF' + hex.replaceFirst('#', '')), radix: 16));
    return Tooltip(
      message: hex,
      child: GestureDetector(
        onTap: onSelected,
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
              ? Icon(Icons.check_rounded,
                  color: ThemePaletteDefaults.bestForeground(hex) == '#FFFFFF'
                      ? Colors.white
                      : Colors.black,
                  size: 20)
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
          for (final id in [
            'welcome',
            'notepad',
            'code_editor',
            'terminal',
            'explorer',
            'browser',
            'settings'
          ])
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
                        Text('app.$id'.tr(),
                            style: TextStyle(
                                color: p.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Built-in RemoteOS application',
                            style: TextStyle(
                                color: p.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.textSecondary,
                      minimumSize: const Size(72, 30),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
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
        _sectionHeader(
            p, Icons.network_check_rounded, 'settings.page.network'.tr(),
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
        _sectionHeader(
            p, Icons.developer_mode_rounded, 'settings.page.developer'.tr(),
            subtitle: 'settings.developer_mode.description'.tr()),
        const SizedBox(height: 20),
        _card(p, [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('settings.developer_mode.title'.tr(),
                        style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                        'Install sideloaded packages and debug via local bridge.',
                        style: TextStyle(color: p.textSecondary, fontSize: 12)),
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

  // ======= Image Mirrors Page =======
  Widget _buildImageMirrorsPage(ThemePalette p) {
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
                      color: p.textPrimary)),
              const SizedBox(height: 2),
              Text('settings.image_mirrors.description'.tr(),
                  style: TextStyle(
                      fontSize: 13, color: p.textSecondary, height: 1.35)),
            ],
          ),
        ),
        _card(p, [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newMirrorName,
                  style: TextStyle(color: p.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'settings.image_mirrors.new_name'.tr(),
                    labelStyle: TextStyle(color: p.textSecondary, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _newMirrorEndpoint,
                  style: TextStyle(color: p.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'settings.image_mirrors.new_endpoint'.tr(),
                    labelStyle: TextStyle(color: p.textSecondary, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _addImageMirror,
                icon: const Icon(Icons.add, size: 16),
                label: Text('common.create'.tr(), style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
          if (_imageMirrorStatus.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_imageMirrorStatus,
                style: TextStyle(color: p.textTertiary, fontSize: 12)),
          ],
        ]),
        const SizedBox(height: 16),
        _sectionTitle(p, 'settings.image_mirrors.registries'.tr()),
        const SizedBox(height: 8),
        for (int i = 0; i < _imageMirrors.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _buildImageMirrorTile(p, _imageMirrors[i]),
        ],
      ],
    );
  }

  void _addImageMirror() {
    final name = _newMirrorName.text.trim();
    final endpoint = _newMirrorEndpoint.text.trim();
    if (name.isEmpty || endpoint.isEmpty) {
      setState(() => _imageMirrorStatus = 'settings.image_mirrors.required'.tr());
      return;
    }
    setState(() {
      _imageMirrors.add(_ImageMirrorUi(
        id: 'm_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        endpoint: endpoint,
        isDefault: false,
        isSelected: false,
      ));
      _imageMirrorStatus = 'settings.image_mirrors.added'.tr();
    });
    _newMirrorName.clear();
    _newMirrorEndpoint.clear();
  }

  Widget _buildImageMirrorTile(ThemePalette p, _ImageMirrorUi mirror) {
    return _card(p, [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(mirror.name,
                        style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    if (mirror.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.accentMuted,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('settings.image_mirrors.default'.tr(),
                            style: TextStyle(
                                color: p.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                    if (mirror.isSelected && !mirror.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('settings.image_mirrors.in_use'.tr(),
                            style: TextStyle(
                                color: p.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(mirror.endpoint,
                    style: TextStyle(color: p.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: mirror.isDefault
                ? () {
                    setState(() {
                      for (final m in _imageMirrors) {
                        m.isSelected = false;
                      }
                      _imageMirrorStatus =
                          'settings.image_mirrors.default_selected'.tr();
                    });
                  }
                : () {
                    setState(() {
                      for (final m in _imageMirrors) {
                        m.isSelected = false;
                      }
                      mirror.isSelected = true;
                      _imageMirrorStatus =
                          'settings.image_mirrors.selected'.tr(args: [mirror.name]);
                    });
                  },
            style: OutlinedButton.styleFrom(
              foregroundColor: p.textSecondary,
              minimumSize: const Size(72, 30),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: Text('settings.image_mirrors.select'.tr()),
          ),
          if (!mirror.isDefault) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'common.delete'.tr(),
              onPressed: () {
                setState(() {
                  _imageMirrors.remove(mirror);
                  _imageMirrorStatus = 'settings.image_mirrors.removed'.tr();
                });
              },
              icon: Icon(Icons.delete_outline_rounded,
                  size: 18, color: p.textTertiary),
            ),
          ],
        ],
      ),
    ]);
  }

  // ======= Default Apps Page =======
  Widget _buildDefaultAppsPage(ThemePalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('settings.page.default_apps'.tr(),
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary)),
              const SizedBox(height: 2),
              Text('settings.default_apps.description'.tr(),
                  style: TextStyle(
                      fontSize: 13, color: p.textSecondary, height: 1.35)),
            ],
          ),
        ),
        Row(
          children: [
            FilledButton.icon(
              onPressed: _addDefaultMapping,
              icon: const Icon(Icons.add, size: 16),
              label: Text('settings.default_apps.add'.tr(),
                  style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_defaultMappings.isEmpty)
          Text('settings.default_apps.empty'.tr(),
              style: TextStyle(color: p.textTertiary, fontSize: 12))
        else
          for (int i = 0; i < _defaultMappings.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _buildDefaultAppRow(p, _defaultMappings[i]),
          ],
      ],
    );
  }

  void _addDefaultMapping() {
    final usedSchemes = _defaultMappings.map((m) => m.scheme.toLowerCase()).toSet();
    String pick = _availableSchemes.firstWhere(
        (s) => !usedSchemes.contains(s.toLowerCase()),
        orElse: () => 'http');
    setState(() {
      _defaultMappings.add(_DefaultAppMappingUi(
        scheme: pick,
        appId: _appOptions.first.id,
      ));
    });
    _persistDefaultApps();
  }

  List<_AppOptionUi> _compatibleAppsFor(String scheme) {
    if (scheme.startsWith('.')) {
      final candidates = _appOptions
          .where((app) => app.extensions
              .any((ext) => ext.toLowerCase() == scheme.toLowerCase()))
          .toList();
      if (candidates.isNotEmpty) return candidates;
      return _appOptions.where((app) => app.extensions.isNotEmpty).toList();
    }
    return _appOptions
        .where((app) =>
            const {'http', 'https', 'mailto', 'ftp'}.contains(scheme.toLowerCase()) ||
            app.schemes.any(
                (s) => s.toLowerCase() == scheme.toLowerCase()))
        .toList();
  }

  Widget _buildDefaultAppRow(ThemePalette p, _DefaultAppMappingUi mapping) {
    final schemeInputKey = GlobalKey<FormFieldState>();
    final schemeCtrl = TextEditingController(text: mapping.scheme);
    final compatible = _compatibleAppsFor(mapping.scheme);
    final selectedApp = _appOptions.firstWhere((a) => a.id == mapping.appId,
        orElse: () => compatible.isNotEmpty ? compatible.first : _appOptions.first);
    return _card(p, [
      Row(
        children: [
          SizedBox(
            width: 200,
            child: TextFormField(
              key: schemeInputKey,
              controller: schemeCtrl,
              style: TextStyle(color: p.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                labelText: 'settings.default_apps.scheme'.tr(),
                labelStyle: TextStyle(color: p.textSecondary, fontSize: 12),
              ),
              onFieldSubmitted: (value) {
                final v = value.trim();
                if (v.isEmpty) return;
                setState(() => mapping.scheme = v);
                _persistDefaultApps();
              },
              onChanged: (value) {
                final v = value.trim();
                if (v.isEmpty) return;
                mapping.scheme = v;
              },
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: compatible.any((a) => a.id == selectedApp.id)
                  ? selectedApp.id
                  : (compatible.isNotEmpty ? compatible.first.id : _appOptions.first.id),
              isExpanded: true,
              style: TextStyle(color: p.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                labelText: 'settings.default_apps.application'.tr(),
                labelStyle: TextStyle(color: p.textSecondary, fontSize: 12),
              ),
              items: [
                for (final app in (compatible.isNotEmpty ? compatible : _appOptions))
                  DropdownMenuItem(
                    value: app.id,
                    child: Text(app.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.textPrimary, fontSize: 13)),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => mapping.appId = value);
                _persistDefaultApps();
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'common.delete'.tr(),
            onPressed: () {
              setState(() => _defaultMappings.remove(mapping));
              _persistDefaultApps();
            },
            icon: Icon(Icons.delete_outline_rounded,
                size: 18, color: p.textTertiary),
          ),
        ],
      ),
    ]);
  }

  // ======= Shared UI helpers =======
  Widget _sectionHeader(ThemePalette p, IconData icon, String title,
      {String? subtitle}) {
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
              Text(title,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: p.textPrimary)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 13, color: p.textSecondary, height: 1.35)),
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
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: p.textSecondary),
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

  Widget _infoRow(ThemePalette p, String label, String value,
      {Color? valueColor}) {
    return Row(
      children: [
        SizedBox(
          width: 180,
          child: Text(label,
              style: TextStyle(color: p.textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
                color: valueColor ?? p.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
