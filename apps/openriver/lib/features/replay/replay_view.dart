import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openriver_ui/openriver_ui.dart';

import '../../app/app_context.dart';
import 'action_log.dart';
import 'replay_controls.dart';
import 'replay_cubit.dart';
import 'replay_format.dart';
import 'replay_models.dart';
import 'replay_table.dart';

/// A full hand replayer: the table, the step announcement, controls, and
/// the action log. Reads its [ReplayCubit] from the context.
///
/// Expanded and wider regions put the log beside the table; medium regions
/// put it in a bottom panel; compact ones open it as a sheet. Keyboard:
/// ← and → step, Home and End jump to the ends, Space plays or pauses,
/// and 1–5 jump to a street.
class ReplayView extends StatefulWidget {
  const ReplayView({super.key, this.onClose});

  /// Shows a close button in the header when set.
  final VoidCallback? onClose;

  /// A page route showing [replay], for pushing inside a destination.
  static Route<void> route(Replay replay) => PageRouteBuilder<void>(
    pageBuilder: (context, _, _) => BlocProvider(
      create: (_) => ReplayCubit(replay),
      child: ReplayView(onClose: () => Navigator.of(context).maybePop()),
    ),
  );

  @override
  State<ReplayView> createState() => _ReplayViewState();
}

class _StepIntent extends Intent {
  const _StepIntent(this.delta);
  final int delta;
}

class _EndIntent extends Intent {
  const _EndIntent({required this.last});
  final bool last;
}

class _PlayIntent extends Intent {
  const _PlayIntent();
}

class _StreetIntent extends Intent {
  const _StreetIntent(this.street);
  final Street street;
}

class _ReplayViewState extends State<ReplayView> {
  final _focus = FocusNode(debugLabel: 'ReplayView');

  static final _shortcuts = <ShortcutActivator, Intent>{
    const SingleActivator(LogicalKeyboardKey.arrowLeft): const _StepIntent(-1),
    const SingleActivator(LogicalKeyboardKey.arrowRight): const _StepIntent(1),
    const SingleActivator(LogicalKeyboardKey.home): const _EndIntent(
      last: false,
    ),
    const SingleActivator(LogicalKeyboardKey.end): const _EndIntent(last: true),
    const SingleActivator(LogicalKeyboardKey.space): const _PlayIntent(),
    for (final (index, street) in Street.values.indexed) ...{
      SingleActivator(_digits[index]): _StreetIntent(street),
      SingleActivator(_numpad[index]): _StreetIntent(street),
    },
  };

  static const _digits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
  ];

  static const _numpad = [
    LogicalKeyboardKey.numpad1,
    LogicalKeyboardKey.numpad2,
    LogicalKeyboardKey.numpad3,
    LogicalKeyboardKey.numpad4,
    LogicalKeyboardKey.numpad5,
  ];

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Space plays or pauses, unless a focused control inside the view
  /// handles activation itself, such as a button or switch.
  void _space() {
    final focused = primaryFocus?.context;
    if (focused != null && primaryFocus != _focus) {
      final activate = Actions.maybeFind<ActivateIntent>(focused);
      if (activate != null &&
          activate.isActionEnabled &&
          activate.isEnabled(const ActivateIntent())) {
        Actions.invoke(focused, const ActivateIntent());
        return;
      }
    }
    context.read<ReplayCubit>().togglePlay();
  }

  void _openLog(BuildContext context) {
    final cubit = context.read<ReplayCubit>();
    showRiverOverlay<void>(
      context: context,
      title: context.app.localizations.replayActionLog,
      builder: (overlayContext) => BlocProvider.value(
        value: cubit,
        child: ActionLog(
          onSelected: () => Navigator.of(overlayContext).maybePop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.app.localizations;
    final cubit = context.read<ReplayCubit>();
    final content = context.app.responsive.content;
    final spacing = context.app.theme.spacing;
    final compact = content == RiverWindowClass.compact;
    final side = content >= RiverWindowClass.expanded;

    final main = SingleChildScrollView(
      primary: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TableArea(),
          SizedBox(height: spacing.lg),
          const _Announcement(),
          SizedBox(height: spacing.lg),
          ReplayControls(
            extraActions: [
              if (compact)
                RiverIconButton(
                  icon: LucideIcons.listOrdered,
                  label: strings.replayShowActionLog,
                  onPressed: () => _openLog(context),
                ),
            ],
          ),
        ],
      ),
    );

    final log = _LogPanel(title: strings.replayActionLog);
    final Widget body;
    if (side) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: main),
          SizedBox(width: spacing.xl),
          SizedBox(width: 340, child: log),
        ],
      );
    } else if (compact) {
      body = main;
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 2, child: main),
          SizedBox(height: spacing.lg),
          Expanded(child: log),
        ],
      );
    }

    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: {
          _StepIntent: CallbackAction<_StepIntent>(
            onInvoke: (intent) =>
                cubit.jumpTo(cubit.state.index + intent.delta),
          ),
          _EndIntent: CallbackAction<_EndIntent>(
            onInvoke: (intent) => intent.last ? cubit.last() : cubit.first(),
          ),
          _PlayIntent: CallbackAction<_PlayIntent>(onInvoke: (_) => _space()),
          _StreetIntent: CallbackAction<_StreetIntent>(
            onInvoke: (intent) => cubit.jumpToStreet(intent.street),
          ),
        },
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          child: RiverPage(
            width: RiverPageWidth.full,
            scrollable: false,
            header: RiverPageHeader(
              title: strings.replayTitle,
              showShellAction: false,
              actions: [
                if (widget.onClose case final onClose?)
                  RiverIconButton(
                    icon: LucideIcons.x,
                    label: strings.replayClose,
                    onPressed: onClose,
                  ),
              ],
            ),
            body: body,
          ),
        ),
      ),
    );
  }
}

class _TableArea extends StatelessWidget {
  const _TableArea();

  @override
  Widget build(BuildContext context) {
    final strings = context.app.localizations;
    return BlocBuilder<ReplayCubit, ReplayState>(
      builder: (context, state) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ReplayTable(
            replay: state.replay,
            step: state.step,
            format: ReplayFormat(
              state.replay,
              strings,
              inBigBlinds: state.amountsInBigBlinds,
            ),
            focusSeat: state.focusSeat,
            revealAll: state.revealAll,
          ),
        ),
      ),
    );
  }
}

/// The current step in words, announced as it changes.
class _Announcement extends StatelessWidget {
  const _Announcement();

  @override
  Widget build(BuildContext context) {
    final strings = context.app.localizations;
    final theme = context.app.theme;
    return BlocBuilder<ReplayCubit, ReplayState>(
      buildWhen: (previous, current) =>
          previous.index != current.index ||
          previous.amountsInBigBlinds != current.amountsInBigBlinds,
      builder: (context, state) {
        final format = ReplayFormat(
          state.replay,
          strings,
          inBigBlinds: state.amountsInBigBlinds,
        );
        return Semantics(
          liveRegion: true,
          child: Text(
            format.describe(state.step),
            key: const ValueKey('replay-announcement'),
            textAlign: TextAlign.center,
            style: theme.textTheme.large,
          ),
        );
      },
    );
  }
}

class _LogPanel extends StatelessWidget {
  const _LogPanel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = context.app.theme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.card,
        borderRadius: theme.radius,
        border: Border.all(color: theme.colors.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.all(theme.spacing.sm),
              child: Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.h4),
              ),
            ),
            const Expanded(child: ActionLog()),
          ],
        ),
      ),
    );
  }
}
