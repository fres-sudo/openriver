import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/hands/hands_page.dart';
import '../features/library/library_page.dart';
import '../features/settings/settings_page.dart';
import 'app_shell.dart';

/// Route paths. Navigate with these constants, never string literals.
abstract final class AppRoutes {
  static const library = '/library';
  static const hands = '/hands';
  static const settings = '/settings';
}

/// Top-level destinations, in shell order. Each is one router branch.
enum AppDestination { library, hands, settings }

/// The router and the per-destination state it needs.
///
/// Each destination is a branch with its own navigator, so its pages and
/// scroll position survive switching away. Create one per app and dispose
/// it with the app.
final class AppNavigation {
  AppNavigation() {
    router = GoRouter(
      initialLocation: AppRoutes.library,
      // Unknown paths, such as stale deep links, go to the library.
      onException: (_, _, router) => router.go(AppRoutes.library),
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) =>
              AppShell(shell: shell, navigation: this),
          branches: [
            _branch(
              AppDestination.library,
              AppRoutes.library,
              const LibraryPage(),
            ),
            _branch(AppDestination.hands, AppRoutes.hands, const HandsPage()),
            _branch(
              AppDestination.settings,
              AppRoutes.settings,
              const SettingsPage(),
            ),
          ],
        ),
      ],
    );
  }

  late final GoRouter router;

  final _navigators = [
    for (final destination in AppDestination.values)
      GlobalKey<NavigatorState>(debugLabel: '${destination.name} navigator'),
  ];

  final _scrollControllers = [
    for (final _ in AppDestination.values) ScrollController(),
  ];

  StatefulShellBranch _branch(
    AppDestination destination,
    String path,
    Widget page,
  ) => StatefulShellBranch(
    navigatorKey: _navigators[destination.index],
    routes: [
      GoRoute(
        path: path,
        // Each route installs its own primary scroll controller; this one
        // takes precedence for the branch's root page, so reselecting the
        // destination can scroll it to the top.
        builder: (_, _) => PrimaryScrollController(
          controller: _scrollControllers[destination.index],
          child: page,
        ),
      ),
    ],
  );

  /// Whether the destination has pages above its root page.
  bool canPop(int index) => _navigators[index].currentState?.canPop() ?? false;

  /// Returns a reselected destination to its root page or, if already there,
  /// scrolls it to the top.
  void reselect(
    StatefulNavigationShell shell,
    int index, {
    required bool reduceMotion,
  }) {
    if (canPop(index)) {
      shell.goBranch(index, initialLocation: true);
      return;
    }
    // The controller belongs to this destination's root page only, so
    // moving every attached position is safe.
    final controller = _scrollControllers[index];
    if (!controller.hasClients) return;
    if (reduceMotion) {
      controller.jumpTo(0);
    } else {
      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void dispose() {
    router.dispose();
    for (final controller in _scrollControllers) {
      controller.dispose();
    }
  }
}
