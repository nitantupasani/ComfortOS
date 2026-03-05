import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';
import '../ui/screens/login_screen.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/dashboard_screen.dart';
import '../ui/screens/vote_screen.dart';
import '../ui/screens/presence_screen.dart';
import '../ui/screens/location_screen.dart';
import '../ui/screens/history_screen.dart';
import '../ui/screens/settings_screen.dart';

/// App Router + Route Guards.
///
/// Flow: Login → Presence (building) → Location (floor/room) → Dashboard.
/// Dashboard, History, Settings accessible via bottom nav.
/// Vote pushed from Dashboard via the CTA button.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final isAuthenticated = auth.isAuthenticated;
      final location = state.matchedLocation;

      // ── Auth guard ──────────────────────────────────────────────────
      if (!isAuthenticated && location != '/login') {
        return '/login';
      }
      if (isAuthenticated && location == '/login') {
        return '/presence';
      }

      // ── Building-context guard ──────────────────────────────────────
      if (isAuthenticated &&
          (location == '/dashboard' ||
           location == '/vote' ||
           location == '/history' ||
           location == '/location')) {
        final presence = ref.read(presenceStateProvider);
        if (presence.activeBuilding == null && location != '/presence') {
          return '/presence';
        }
      }

      // ── Location guard — require floor/room for dashboard ──────────
      if (isAuthenticated && location == '/dashboard') {
        final presence = ref.read(presenceStateProvider);
        if (presence.activeBuilding != null && !presence.hasLocation) {
          return '/location';
        }
      }

      return null; // no redirect
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (ctx, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (ctx, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/presence',
        builder: (ctx, state) => const PresenceScreen(),
      ),
      GoRoute(
        path: '/location',
        builder: (ctx, state) => const LocationScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (ctx, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/vote',
        builder: (ctx, state) => const VoteScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (ctx, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (ctx, state) => const SettingsScreen(),
      ),
    ],
  );
});
