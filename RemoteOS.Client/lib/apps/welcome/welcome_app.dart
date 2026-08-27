import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/theme_service.dart';
import '../../core/apps/app_registry.dart';
import '../../core/window_manager/window_manager.dart';

/// The Welcome / First-time Setup app.
/// Displays quick links to apps, tour steps, and a "Get started" CTA.
class WelcomeApp extends ConsumerWidget {
  const WelcomeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = watchPalette(ref, context);
    final registry = ref.watch(appRegistryProvider);
    final wm = ref.read(windowManagerProvider.notifier);
    final screen = MediaQuery.of(context).size;

    final quickApps = [
      ('explorer', Icons.folder_rounded, Color(0xFFF59E0B)),
      ('browser', Icons.public_rounded, Color(0xFF10B981)),
      ('terminal', Icons.terminal_rounded, Color(0xFF111827)),
      ('settings', Icons.settings_rounded, Color(0xFF6366F1)),
      ('notepad', Icons.edit_note_rounded, Color(0xFF0EA5E9)),
      ('code_editor', Icons.code_rounded, Color(0xFF8B5CF6)),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.accent.withOpacity(0.08),
            palette.appBackground,
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [palette.accent, palette.accentHover],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: palette.accent.withOpacity(0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(Icons.window_rounded,
                      size: 30, color: palette.textOnAccent),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'shell.desktop_display.welcome_heading'.tr(),
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: palette.textPrimary,
                            height: 1.15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'shell.desktop_display.welcome_description'.tr(),
                        style: TextStyle(
                            fontSize: 13,
                            color: palette.textSecondary,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Get started card
            _featureCard(
              palette,
              icon: Icons.rocket_launch_rounded,
              iconBg: palette.accentMuted,
              iconColor: palette.accent,
              title: 'Get productive in 3 quick steps',
              subtitle: 'Connect, customize, and launch your favorite apps.',
              child: Column(
                children: [
                  _stepRow(palette, 1, 'Sign in and connect to your workspace'),
                  _stepRow(palette, 2, 'Personalize your theme and language'),
                  _stepRow(
                      palette, 3, 'Launch apps from the Start menu or desktop'),
                ],
              ),
              footer: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        final settings = registry.get('settings');
                        if (settings != null) {
                          wm.openApp(
                              entry: settings,
                              child: settings.windowBuilder(context),
                              screenSize: screen);
                        }
                      },
                      icon: const Icon(Icons.palette_rounded, size: 16),
                      label:
                          Text('shell.desktop_display.configure_ellipsis'.tr()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Popular apps',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.textSecondary),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.25,
              children: quickApps.map((a) {
                final entry = registry.get(a.$1);
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      if (entry != null) {
                        wm.openApp(
                            entry: entry,
                            child: entry.windowBuilder(context),
                            screenSize: screen);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: palette.borderSubtle),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: a.$3.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(a.$2, size: 20, color: a.$3),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            entry?.nameKey.tr() ?? a.$1,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: palette.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureCard(
    ThemePalette palette, {
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? footer,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.borderSubtle),
        boxShadow: [
          BoxShadow(
              color: palette.shadow.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: palette.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
          if (footer != null) ...[
            const SizedBox(height: 14),
            footer,
          ],
        ],
      ),
    );
  }

  Widget _stepRow(ThemePalette palette, int step, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: palette.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$step',
                style: TextStyle(
                    color: palette.textOnAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 13, color: palette.textPrimary, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
