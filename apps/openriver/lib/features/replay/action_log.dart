import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openriver_ui/openriver_ui.dart';

import '../../app/app_context.dart';
import 'replay_cubit.dart';
import 'replay_format.dart';
import 'replay_models.dart';

/// Every step of the hand, grouped by street. The current step is
/// highlighted and kept in view; selecting a row jumps to it.
class ActionLog extends StatefulWidget {
  const ActionLog({super.key, this.onSelected});

  /// Called after a row is selected, such as to close a sheet.
  final VoidCallback? onSelected;

  @override
  State<ActionLog> createState() => _ActionLogState();
}

class _ActionLogState extends State<ActionLog> {
  final _rowKeys = <int, GlobalKey>{};
  final _controller = ScrollController();

  GlobalKey _keyFor(int index) =>
      _rowKeys.putIfAbsent(index, () => GlobalKey(debugLabel: 'step $index'));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reveal(context.read<ReplayCubit>().state.index, animate: false),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reveal(int index, {bool animate = true}) {
    if (!mounted) return;
    final row = _rowKeys[index]?.currentContext;
    if (row == null) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    Scrollable.ensureVisible(
      row,
      alignment: 0.5,
      duration: animate && !reduceMotion
          ? context.app.theme.durations.normal
          : Duration.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.app.localizations;
    final theme = context.app.theme;
    final spacing = theme.spacing;
    return BlocConsumer<ReplayCubit, ReplayState>(
      listenWhen: (previous, current) => previous.index != current.index,
      listener: (context, state) => WidgetsBinding.instance
          .addPostFrameCallback((_) => _reveal(state.index)),
      buildWhen: (previous, current) =>
          previous.index != current.index ||
          previous.amountsInBigBlinds != current.amountsInBigBlinds,
      builder: (context, state) {
        final format = ReplayFormat(
          state.replay,
          strings,
          inBigBlinds: state.amountsInBigBlinds,
        );
        final children = <Widget>[];
        Street? street;
        for (final (index, step) in state.replay.steps.indexed) {
          if (step.street != street) {
            street = step.street;
            children.add(
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: spacing.sm,
                  top: children.isEmpty ? 0 : spacing.lg,
                  bottom: spacing.xs,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    format.streetName(step.street),
                    style: theme.textTheme.small.copyWith(
                      color: theme.colors.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }
          children.add(
            _LogRow(
              key: _keyFor(index),
              label: format.describe(step),
              current: index == state.index,
              onPressed: () {
                context.read<ReplayCubit>().jumpTo(index);
                widget.onSelected?.call();
              },
            ),
          );
        }
        return SingleChildScrollView(
          controller: _controller,
          primary: false,
          padding: EdgeInsets.symmetric(vertical: spacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        );
      },
    );
  }
}

/// One step in the log: a focusable, selectable row.
class _LogRow extends StatefulWidget {
  const _LogRow({
    super.key,
    required this.label,
    required this.current,
    required this.onPressed,
  });

  final String label;
  final bool current;
  final VoidCallback onPressed;

  @override
  State<_LogRow> createState() => _LogRowState();
}

class _LogRowState extends State<_LogRow> {
  var _focused = false;
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.app.theme;
    final colors = theme.colors;
    final background = widget.current
        ? colors.secondary
        : _hovered
        ? colors.accent
        : null;
    return Semantics(
      button: true,
      selected: widget.current,
      label: widget.label,
      onTap: widget.onPressed,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          onShowFocusHighlight: (focused) => setState(() => _focused = focused),
          onShowHoverHighlight: (hovered) => setState(() => _hovered = hovered),
          mouseCursor: SystemMouseCursors.click,
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: Container(
              constraints: BoxConstraints(minHeight: theme.sizes.minTapTarget),
              alignment: AlignmentDirectional.centerStart,
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.md,
                vertical: theme.spacing.sm,
              ),
              decoration: BoxDecoration(
                color: background,
                borderRadius: theme.radius,
                border: Border.all(
                  color: _focused
                      ? colors.ring
                      : colors.ring.withValues(alpha: 0),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 20,
                    color: widget.current ? colors.primary : null,
                  ),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: theme.textTheme.small.copyWith(
                        color: widget.current
                            ? colors.secondaryForeground
                            : colors.foreground,
                        fontWeight: widget.current ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
