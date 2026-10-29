import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openriver_api/openriver_api.dart';
import 'package:openriver_ui/openriver_ui.dart';

import '../features/library/library_cubit.dart';
import '../features/library/library_page.dart';

class OpenRiverApp extends StatelessWidget {
  const OpenRiverApp({
    super.key,
    required this.core,
    required this.databasePath,
  });

  final OpenRiverCore core;
  final Future<String> Function() databasePath;

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      title: 'OpenRiver',
      color: RiverThemes.light.colorScheme.primary,
      debugShowCheckedModeBanner: false,
      theme: RiverThemes.light,
      darkTheme: RiverThemes.dark,
      localizationsDelegates: const [RiverLocalizations.delegate],
      builder: (context, child) => RiverLayoutScope(child: child!),
      home: BlocProvider(
        create: (_) =>
            LibraryCubit(core: core, databasePath: databasePath)..open(),
        child: const LibraryPage(),
      ),
    );
  }
}
