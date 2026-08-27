import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/theme_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/window_manager/window_manager.dart';

class Taskbar extends ConsumerWidget {
  final VoidCallback onStartPressed;
  final bool isStartOpen;
  final VoidCallback onLogout;

  const Taskbar({
    super.key,
    required this.onStartPressed,
    required this.isStartOpen,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = watchPalette(ref, context);
    final authState = ref.watch(authProvider);
    final windows = ref.watch(windowManagerProvider);
    final wm = ref.read(windowManagerProvider.notifier);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: palette.taskbarBackground,
        border: Border(top: BorderSide(color: palette.borderSubtle, width: 1)),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withOpacity(0.6),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _buildStartButton(palette),
          const SizedBox(width: 4),
          _buildSearchBox(palette),
          const SizedBox(width: 4),
          VerticalDivider(
              width: 1,
              color: palette.borderSubtle,
              thickness: 1,
              indent: 10,
              endIndent: 10),
          const SizedBox(width: 4),
          Expanded(child: _buildAppIcons(palette, windows, wm)),
          const SizedBox(width: 4),
          VerticalDivider(
              width: 1,
              color: palette.borderSubtle,
              thickness: 1,
              indent: 10,
              endIndent: 10),
          const SizedBox(width: 8),
          _buildTrayIcons(palette),
          const SizedBox(width: 8),
          _buildClock(palette),
          const SizedBox(width: 8),
          _buildConnectionButton(context, palette, authState),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildStartButton(ThemePalette palette) {
    return InkWell(
      onTap: onStartPressed,
      borderRadius: BorderRadius.circular(4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isStartOpen ? palette.accentMuted : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.window_rounded,
              size: 18,
              color: isStartOpen ? palette.accent : palette.taskbarForeground,
            ),
            const SizedBox(width: 6),
            Text(
              'shell.taskbar.start'.tr(),
              style: TextStyle(
                color: isStartOpen ? palette.accent : palette.taskbarForeground,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBox(ThemePalette palette) {
    return Container(
      width: 260,
      height: 32,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.borderDefault),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search_rounded, size: 16, color: palette.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              style: TextStyle(color: palette.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'shell.taskbar.search'.tr(),
                hintStyle: TextStyle(color: palette.textTertiary, fontSize: 12),
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildAppIcons(ThemePalette palette, List<RemoteWindow> windows,
      WindowManagerNotifier wm) {
    final grouped = <String, List<RemoteWindow>>{};
    for (final w in windows) {
      grouped.putIfAbsent(w.appId, () => []).add(w);
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: grouped.entries.length,
      separatorBuilder: (_, __) => const SizedBox(width: 2),
      itemBuilder: (context, index) {
        final e = grouped.entries.elementAt(index);
        final list = e.value;
        final first = list.first;
        final hasActive =
            list.any((w) => w.state != RemoteWindowState.minimized);
        return InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () {
            if (list.length == 1) {
              if (list.first.state == RemoteWindowState.minimized) {
                wm.restore(list.first.id);
              } else {
                wm.minimize(list.first.id);
              }
            } else {
              wm.focus(list.last.id);
            }
          },
          child: Container(
            width: 44,
            height: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: hasActive
                  ? palette.accent.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border(
                bottom: BorderSide(
                  color: hasActive ? palette.accent : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(first.icon, size: 20, color: palette.taskbarForeground),
                if (list.length > 1)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: palette.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${list.length}',
                        style: TextStyle(
                            color: palette.textOnAccent,
                            fontSize: 8,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrayIcons(ThemePalette palette) {
    return Row(
      children: [
        _trayIcon(Icons.wifi, palette, 'Network'),
        _trayIcon(Icons.volume_up_rounded, palette, 'Volume'),
        _trayIcon(Icons.battery_6_bar_rounded, palette, 'Battery'),
        _trayIcon(Icons.keyboard_arrow_up_rounded, palette, 'Expand'),
      ],
    );
  }

  Widget _trayIcon(IconData icon, ThemePalette palette, String tooltip) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: SizedBox(
          width: 24,
          height: 24,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () {},
            child: Icon(icon, size: 16, color: palette.taskbarForeground),
          ),
        ),
      ),
    );
  }

  Widget _buildClock(ThemePalette palette) {
    return StreamBuilder(
      stream:
          Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now()),
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final now = snapshot.data!;
        final time = TimeOfDay.fromDateTime(now);
        final hours = time.hour.toString().padLeft(2, '0');
        final minutes = time.minute.toString().padLeft(2, '0');
        final date = '${now.month}/${now.day}/${now.year}';
        return InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$hours:$minutes',
                  style:
                      TextStyle(color: palette.taskbarForeground, fontSize: 12),
                ),
                Text(
                  date,
                  style: TextStyle(color: palette.textSecondary, fontSize: 10),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionButton(
    BuildContext context,
    ThemePalette palette,
    AuthSessionState auth,
  ) {
    return PopupMenuButton<void>(
      tooltip: 'shell.connection.info_tooltip'.tr(),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 260),
      offset: const Offset(0, -10),
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'shell.connection.info'.tr(),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary),
                ),
                const SizedBox(height: 8),
                _connectionRow(palette, 'shell.connection.server'.tr(),
                    auth.serverUrl ?? 'shell.connection.not_connected'.tr()),
                _connectionRow(palette, 'shell.connection.user'.tr(),
                    auth.username ?? 'shell.connection.unknown_user'.tr()),
                _connectionRow(palette, 'shell.connection.workspace'.tr(),
                    'shell.connection.default_workspace'.tr()),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          onTap: onLogout,
          child: Row(
            children: [
              Icon(Icons.logout_outlined, size: 18, color: palette.textPrimary),
              const SizedBox(width: 10),
              Text(
                'shell.connection.close'.tr(),
                style: TextStyle(color: palette.textPrimary, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: palette.borderDefault),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_outlined, size: 16, color: palette.success),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  auth.username?.truncate(16) ??
                      'shell.connection.not_connected'.tr(),
                  style: TextStyle(
                      color: palette.taskbarForeground,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
                Text(
                  auth.serverUrl
                          ?.replaceFirst('http://', '')
                          .replaceFirst('https://', '')
                          .truncate(16) ??
                      '',
                  style: TextStyle(color: palette.textTertiary, fontSize: 9),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _connectionRow(ThemePalette palette, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

extension _StringTruncate on String {
  String truncate(int len) =>
      length <= len ? this : '${substring(0, len - 1)}…';
}
