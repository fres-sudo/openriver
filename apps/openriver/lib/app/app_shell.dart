import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openriver_ui/openriver_ui.dart';

import '../features/import/import_flow.dart';
import '../features/library/library_cubit.dart';
import 'app_context.dart';
import 'app_navigation.dart';

/// The app frame: [RiverShell] around the router's destination branches.
///
/// System back pops within the current destination first. At the root of
/// any destination but the library, it goes to the library; at the
/// library's root, it leaves the app.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell, required this.navigation});

  final StatefulNavigationShell shell;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    final strings = context.app.localizations;
    final atHome = shell.currentIndex == AppDestination.library.index;

    return PopScope(
      canPop: atHome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !atHome) shell.goBranch(AppDestination.library.index);
      },
      child: BlocBuilder<LibraryCubit, LibraryState>(
        buildWhen: (previous, current) =>
            _actionState(previous) != _actionState(current),
        builder: (context, state) => RiverShell(
          destinations: [
            RiverDestination(
              label: strings.navLibrary,
              icon: LucideIcons.library,
            ),
            RiverDestination(label: strings.navHands, icon: LucideIcons.list),
            RiverDestination(
              label: strings.navSettings,
              icon: LucideIcons.settings,
            ),
          ],
          selectedIndex: shell.currentIndex,
          onDestinationSelected: shell.goBranch,
          onDestinationReselected: (index) => navigation.reselect(
            shell,
            index,
            reduceMotion: MediaQuery.disableAnimationsOf(context),
          ),
          brand: Text(strings.appTitle),
          primaryAction: RiverShellAction(
            label: strings.importAction,
            icon: LucideIcons.upload,
            busy: _actionState(state) == _ActionState.busy,
            onPressed: _actionState(state) == _ActionState.unavailable
                ? null
                : () => ImportFlow.start(context),
          ),
          body: shell,
        ),
      ),
    );
  }
}

enum _ActionState { unavailable, ready, busy }

/// Import needs an open library and no import already running.
_ActionState _actionState(LibraryState state) => switch (state) {
  LibraryReady(importing: true) => _ActionState.busy,
  LibraryReady() => _ActionState.ready,
  _ => _ActionState.unavailable,
};
