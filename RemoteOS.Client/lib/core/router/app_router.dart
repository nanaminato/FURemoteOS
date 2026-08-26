import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../screens/login/login_screen.dart';
import '../screens/desktop/desktop_screen.dart';

final router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/desktop',
      builder: (context, state) => const DesktopScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.uri}'),
    ),
  ),
);
