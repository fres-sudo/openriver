import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openriver_api/openriver_api.dart';

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
    ThemeData theme(Brightness brightness) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF146B58),
        brightness: brightness,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );

    return MaterialApp(
      title: 'OpenRiver',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: BlocProvider(
        create: (_) =>
            LibraryCubit(core: core, databasePath: databasePath)..open(),
        child: const LibraryPage(),
      ),
    );
  }
}
