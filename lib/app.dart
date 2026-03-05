import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'ui/widgets/error_boundary.dart';

/// Root application widget.
///
/// Relationships (C4):
///   Wraps the entire widget tree in [ErrorBoundary] (Logging + Error Boundary → UI).
///   Uses [GoRouter] provided by [appRouterProvider] for role-based routing.
class ComfortOSApp extends ConsumerWidget {
  const ComfortOSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return ErrorBoundary(
      child: MaterialApp.router(
        title: 'ComfortOS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3B82F6), // blue brand — matches dashboard
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'Inter',
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            filled: true,
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3B82F6),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        routerConfig: router,
      ),
    );
  }
}
