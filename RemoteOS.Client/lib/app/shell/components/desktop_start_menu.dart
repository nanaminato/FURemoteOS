// Desktop start menu, extracted from screens/widgets/start_menu.dart so the
// desktop shell owns all its composite layout pieces (ARCHITECTURE.md § 17).
//
// UI-only responsibilities: rendering the pinned + app registry grid, the
// search filter, and the footer actions.  All side effects (open app, log
// out, shutdown) are reported via callbacks and handled by the shell VM.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/apps/app_registry.dart';
import '../../../../core/theme/theme_service.dart';

class DesktopStartMenu extends ConsumerStatefulWidget {
  final ValueChanged<AppRegistryEntry> onAppSelected;
  final VoidCallback onClose;
  final Future<void> Function() onLogout;
  final Future<void> Function() onShutdown;

  const DesktopStartMenu({
    super.key,
    required this.onAppSelected,
    required this.onClose,
    required this.onLogout,
    required this.onShutdown,
  });

  @override
  ConsumerState<DesktopStartMenu> createState() => _DesktopStartMenuState();
}

class _DesktopStartMenuState extends ConsumerState<DesktopStartMenu> {
  final _searchController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    final registry = ref.watch(appRegistryProvider);
    final apps = registry.all
        .where((e) =>
            _filter.isEmpty ||
            e.id.toLowerCase().contains(_filter.toLowerCase()) ||
            e.nameKey.tr().toLowerCase().contains(_filter.toLowerCase()))
        .toList()
      ..sort((a, b) => a.nameKey.tr().compareTo(b.nameKey.tr()));

    const pinnedIds = [
      'explorer',
      'browser',
      'terminal',
      'settings',
      'code_editor',
      'notepad',
    ];
    final pinned = registry.all.where((e) => pinnedIds.contains(e.id)).toList()
      ..sort(
          (a, b) => pinnedIds.indexOf(a.id).compareTo(pinnedIds.indexOf(b.id)));

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 440,
        height: 560,
        decoration: BoxDecoration(
          color: palette.startMenuBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.borderDefault),
          boxShadow: [
            BoxShadow(
              color: palette.flyoutShadow,
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _buildHeader(palette),
            _buildSearch(palette),
            _buildTabs(),
            Expanded(
              child: _filter.isEmpty
                  ? _buildPinnedAndAll(palette, pinned, apps)
                  : _buildSearchResults(palette, apps),
            ),
            _buildFooter(palette),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemePalette palette) {
    return Container(
      height: 64,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [palette.accent, palette.accentHover],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.window_rounded,
                color: palette.textOnAccent, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'RemoteOS',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              Text(
                'Start',
                style: TextStyle(fontSize: 12, color: palette.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(ThemePalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: palette.surfaceSunken,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.borderSubtle),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _filter = v),
          autofocus: true,
          style: TextStyle(fontSize: 13, color: palette.textPrimary),
          decoration: InputDecoration(
            hintText: 'shell.taskbar.search'.tr(),
            hintStyle: TextStyle(color: palette.textTertiary, fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded,
                size: 18, color: palette.textSecondary),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 30, minHeight: 36),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
      child: Row(
        children: [
          Text(
            'shell.desktop_display.title'.tr(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedAndAll(
    ThemePalette palette,
    List<AppRegistryEntry> pinned,
    List<AppRegistryEntry> apps,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pinned',
            style: TextStyle(
              fontSize: 11,
              color: palette.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildGrid(palette, pinned),
          const SizedBox(height: 16),
          Divider(color: palette.borderSubtle, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'All applications',
                style: TextStyle(
                  fontSize: 11,
                  color: palette.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${apps.length}',
                style: TextStyle(fontSize: 11, color: palette.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildGrid(palette, apps),
        ],
      ),
    );
  }

  Widget _buildSearchResults(
      ThemePalette palette, List<AppRegistryEntry> apps) {
    if (apps.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 48, color: palette.textTertiary),
            const SizedBox(height: 8),
            Text(
              'No results for "$_filter"',
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
      child: _buildGrid(palette, apps),
    );
  }

  Widget _buildGrid(ThemePalette palette, List<AppRegistryEntry> apps) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        mainAxisExtent: 92,
      ),
      itemCount: apps.length,
      itemBuilder: (context, index) => _buildAppTile(palette, apps[index]),
    );
  }

  Widget _buildAppTile(ThemePalette palette, AppRegistryEntry entry) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => widget.onAppSelected(entry),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(entry.icon, size: 28, color: palette.textPrimary),
              const SizedBox(height: 6),
              Text(
                entry.nameKey.tr(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: palette.textPrimary,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(ThemePalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.borderSubtle)),
        color: palette.surfaceRaised,
      ),
      child: Row(
        children: [
          _footerItem(palette, Icons.person_outline_rounded, 'User'),
          const Spacer(),
          _footerItem(
            palette,
            Icons.logout_outlined,
            'shell.connection.close'.tr(),
            onTap: widget.onLogout,
          ),
          const SizedBox(width: 4),
          _powerButton(palette),
        ],
      ),
    );
  }

  Widget _footerItem(
    ThemePalette palette,
    IconData icon,
    String label, {
    Future<void> Function()? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: palette.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(fontSize: 12, color: palette.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _powerButton(ThemePalette palette) {
    return PopupMenuButton<void>(
      tooltip: 'shell.shutdown'.tr(),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 160),
      position: PopupMenuPosition.over,
      offset: const Offset(0, -8),
      itemBuilder: (_) => [
        PopupMenuItem(
          onTap: () => Future.delayed(
              const Duration(milliseconds: 100), widget.onLogout),
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18, color: palette.textPrimary),
              const SizedBox(width: 10),
              Text('shell.connection.close'.tr(),
                  style: TextStyle(fontSize: 13, color: palette.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () => Future.delayed(
              const Duration(milliseconds: 100), widget.onShutdown),
          child: Row(
            children: [
              Icon(Icons.power_settings_new_rounded,
                  size: 18, color: palette.danger),
              const SizedBox(width: 10),
              Text('shell.shutdown'.tr(),
                  style: TextStyle(fontSize: 13, color: palette.danger)),
            ],
          ),
        ),
      ],
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Icon(Icons.power_settings_new_rounded,
              size: 18, color: palette.textPrimary),
        ),
      ),
    );
  }
}
