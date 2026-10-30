import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openriver_ui/openriver_ui.dart';

import '../../app/app_context.dart';
import 'replay_cubit.dart';
import 'replay_format.dart';
import 'replay_models.dart';

/// Transport, scrubber, street jumps, speed, and display toggles.
class ReplayControls extends StatelessWidget {
  const ReplayControls({super.key, this.extraActions = const []});

  /// Shown after the transport buttons, such as opening the action log.
  final List<Widget> extraActions;

  static String speedLabel(double speed) =>
      speed == speed.roundToDouble() ? '${speed.toInt()}' : '$speed';

  @override
  Widget build(BuildContext context) {
    final strings = context.app.localizations;
    final theme = context.app.theme;
    final spacing = theme.spacing;
    final cubit = context.read<ReplayCubit>();
    return BlocBuilder<ReplayCubit, ReplayState>(
      builder: (context, state) {
        final format = ReplayFormat(state.replay, strings);
        final steps = state.replay.steps.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: spacing.xs,
              runSpacing: spacing.xs,
              children: [
                RiverIconButton(
                  icon: LucideIcons.skipBack,
                  label: strings.replayFirst,
                  mirrorInRtl: true,
                  onPressed: state.atStart ? null : cubit.first,
                ),
                RiverIconButton(
                  icon: LucideIcons.stepBack,
                  label: strings.replayPrevious,
                  mirrorInRtl: true,
                  onPressed: state.atStart ? null : cubit.previous,
                ),
                RiverIconButton(
                  icon: state.playing ? LucideIcons.pause : LucideIcons.play,
                  label: state.playing
                      ? strings.replayPause
                      : strings.replayPlay,
                  mirrorInRtl: !state.playing,
                  onPressed: steps > 1 ? cubit.togglePlay : null,
                ),
                RiverIconButton(
                  icon: LucideIcons.stepForward,
                  label: strings.replayNext,
                  mirrorInRtl: true,
                  onPressed: state.atEnd ? null : cubit.next,
                ),
                RiverIconButton(
                  icon: LucideIcons.skipForward,
                  label: strings.replayLast,
                  mirrorInRtl: true,
                  onPressed: state.atEnd ? null : cubit.last,
                ),
                ...extraActions,
              ],
            ),
            SizedBox(height: spacing.sm),
            Text(
              strings.replayStepOf(state.index + 1, steps),
              textAlign: TextAlign.center,
              style: theme.textTheme.muted,
            ),
            RiverStepSlider(
              value: state.index,
              max: state.lastIndex,
              label: strings.replayScrubber,
              valueLabel: (index) => strings.replayStepOf(index + 1, steps),
              onChanged: steps > 1 ? cubit.jumpTo : null,
            ),
            SizedBox(height: spacing.sm),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: spacing.xs,
              runSpacing: spacing.xs,
              children: [
                for (final street in Street.values)
                  _Choice(
                    label: format.streetName(street),
                    selected: state.step.street == street,
                    onPressed: state.firstStepOf(street) == null
                        ? null
                        : () => cubit.jumpToStreet(street),
                  ),
              ],
            ),
            SizedBox(height: spacing.md),
            Semantics(
              container: true,
              label: strings.replaySpeed,
              explicitChildNodes: true,
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: spacing.xs,
                runSpacing: spacing.xs,
                children: [
                  ExcludeSemantics(
                    child: Text(
                      strings.replaySpeed,
                      style: theme.textTheme.small,
                    ),
                  ),
                  for (final speed in ReplayCubit.speeds)
                    _Choice(
                      label: strings.replaySpeedValue(speedLabel(speed)),
                      selected: state.speed == speed,
                      exclusive: true,
                      onPressed: () => cubit.setSpeed(speed),
                    ),
                ],
              ),
            ),
            SizedBox(height: spacing.md),
            _Toggle(
              label: strings.replayAmountsInBigBlinds,
              value: state.amountsInBigBlinds,
              onChanged: cubit.setAmountsInBigBlinds,
            ),
            SizedBox(height: spacing.sm),
            _Toggle(
              label: strings.replayHideOpponentCards,
              value: state.hideOpponentCards,
              onChanged: cubit.setHideOpponentCards,
            ),
          ],
        );
      },
    );
  }
}

/// A button that shows whether it is the current choice.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.exclusive = false,
  });

  final String label;
  final bool selected;
  final bool exclusive;
  final VoidCallback? onPressed;

  @override
  // One node: the button's label, role, and state, plus selection.
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: exclusive,
      child: RiverButton(
        label: label,
        variant: selected
            ? RiverButtonVariant.primary
            : RiverButtonVariant.outline,
        onPressed: onPressed,
      ),
    ),
  );
}

/// A labeled switch that also toggles with Enter and Space while focused.
class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Actions(
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          onChanged(!value);
          return null;
        },
      ),
    },
    child: MergeSemantics(
      child: Semantics(
        onTap: () => onChanged(!value),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!value),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: context.app.theme.sizes.minTapTarget,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ShadSwitch(
                value: value,
                onChanged: onChanged,
                label: Text(label),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
