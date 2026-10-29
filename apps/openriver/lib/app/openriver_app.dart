import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openriver_api/openriver_api.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'design_system.dart';
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
      color: OpenRiverDesignSystem.lightTheme.colorScheme.primary,
      debugShowCheckedModeBanner: false,
      theme: OpenRiverDesignSystem.lightTheme,
      darkTheme: OpenRiverDesignSystem.darkTheme,
      home: BlocProvider(
        create: (_) =>
            LibraryCubit(core: core, databasePath: databasePath)..open(),
        child: const LibraryPage(),
      ),
    );
  }
}
