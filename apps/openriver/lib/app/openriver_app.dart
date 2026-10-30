import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openriver_api/openriver_api.dart';
import 'package:openriver_ui/openriver_ui.dart';

import '../features/import/import_flow.dart';
import '../features/library/library_cubit.dart';
import '../l10n/generated/app_localizations.dart';
import 'app_navigation.dart';

/// Composition root: the Rust core, library state, router, themes, and
/// localization.
class OpenRiverApp extends StatefulWidget {
  const OpenRiverApp({
    super.key,
    required this.core,
    required this.databasePath,
    this.chooseHandHistory = chooseHandHistoryFile,
  });

  final OpenRiverCore core;
  final Future<String> Function() databasePath;
  final HandHistoryChooser chooseHandHistory;

  @override
  State<OpenRiverApp> createState() => _OpenRiverAppState();
}

class _OpenRiverAppState extends State<OpenRiverApp> {
  late final _library = LibraryCubit(
    core: widget.core,
    databasePath: widget.databasePath,
  )..open();
  final _navigation = AppNavigation();

  @override
  void dispose() {
    _navigation.dispose();
    _library.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepositoryProvider.value(
    value: widget.chooseHandHistory,
    child: BlocProvider.value(
      value: _library,
      child: ShadApp.router(
        routerConfig: _navigation.router,
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        color: RiverThemes.light.colorScheme.primary,
        debugShowCheckedModeBanner: false,
        theme: RiverThemes.light,
        darkTheme: RiverThemes.dark,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          RiverLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => RiverLayoutScope(child: child!),
      ),
    ),
  );
}
