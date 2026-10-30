import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openriver/features/replay/replay_cubit.dart';
import 'package:openriver/features/replay/replay_models.dart';
import 'package:openriver/features/replay/replay_view.dart';
import 'package:openriver/l10n/generated/app_localizations.dart';
import 'package:openriver_ui/openriver_ui.dart';

/// Pumps a [ReplayView] for [replay] in a themed app of the given surface.
Future<ReplayCubit> pumpReplay(
  WidgetTester tester,
  Replay replay, {
  Size size = const Size(1280, 1400),
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cubit = ReplayCubit(replay);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    ShadApp(
      theme: RiverThemes.light,
      darkTheme: RiverThemes.dark,
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        RiverLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: RiverLayoutScope(child: app!),
      ),
      home: BlocProvider.value(value: cubit, child: const ReplayView()),
    ),
  );
  // ShadApp mounts zero-duration animation timers; pump past them.
  await tester.pump(const Duration(milliseconds: 500));
  return cubit;
}
