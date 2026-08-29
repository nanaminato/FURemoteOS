// Firewall app shell (AGENTS.md § 2 — keep the Apps folder as a thin entry).
//
// Composes the session-scoped [FirewallViewModel] with the feature
// [FirewallView].  Real layout and command wiring live in features/firewall/.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/dependency_injection.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/theme_service.dart';
import '../../features/firewall/presentation/firewall_view.dart';

class FirewallApp extends ConsumerStatefulWidget {
  const FirewallApp({super.key});

  @override
  ConsumerState<FirewallApp> createState() => _FirewallAppState();
}

class _FirewallAppState extends ConsumerState<FirewallApp> {
  @override
  Widget build(BuildContext context) {
    final palette = watchPalette(ref, context);
    final session = ref.watch(authProvider);
    if (!session.isAuthenticated) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'firewall.login_required'.tr(),
            style: TextStyle(color: palette.textPrimary),
          ),
        ),
      );
    }
    // FirewallView internally resolves FirewallViewModel from get_it when no
    // explicit instance is injected, and owns its dispose lifecycle.
    return const FirewallView();
  }
}
