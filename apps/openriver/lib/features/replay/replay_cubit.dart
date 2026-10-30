import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'replay_models.dart';
import 'replay_table.dart';

final class ReplayState {
  const ReplayState({
    required this.replay,
    required this.index,
    this.playing = false,
    this.speed = 1,
    this.amountsInBigBlinds = false,
    this.hideOpponentCards = false,
    this.focusSeat,
  });

  final Replay replay;
  final int index;
  final bool playing;

  /// Playback rate; one step per second at 1.
  final double speed;
  final bool amountsInBigBlinds;

  /// Shows only [focusSeat]'s cards until a showdown step.
  final bool hideOpponentCards;

  /// Seat drawn at the bottom center of the table.
  final int? focusSeat;

  ReplayStep get step => replay.steps[index];
  int get lastIndex => replay.steps.length - 1;
  bool get atStart => index == 0;
  bool get atEnd => index == lastIndex;

  /// Whether every known card is face up at this step.
  bool get revealAll => !hideOpponentCards || step.street == Street.showdown;

  /// The first step on [street], or null if the hand never reached it.
  int? firstStepOf(Street street) {
    for (var i = 0; i < replay.steps.length; i++) {
      if (replay.steps[i].street == street) return i;
    }
    return null;
  }

  ReplayState copyWith({
    int? index,
    bool? playing,
    double? speed,
    bool? amountsInBigBlinds,
    bool? hideOpponentCards,
  }) => ReplayState(
    replay: replay,
    index: index ?? this.index,
    playing: playing ?? this.playing,
    speed: speed ?? this.speed,
    amountsInBigBlinds: amountsInBigBlinds ?? this.amountsInBigBlinds,
    hideOpponentCards: hideOpponentCards ?? this.hideOpponentCards,
    focusSeat: focusSeat,
  );
}

/// Steps through one replay. The cubit only moves an index; every table
/// state it exposes was computed in Rust.
class ReplayCubit extends Cubit<ReplayState> {
  ReplayCubit(Replay replay, {int? focusSeat})
    : assert(replay.steps.isNotEmpty),
      super(
        ReplayState(
          replay: replay,
          index: 0,
          focusSeat: focusSeat ?? ReplayTable.defaultFocusSeat(replay),
        ),
      );

  static const speeds = [0.5, 1.0, 2.0, 4.0];
  static const _stepInterval = Duration(milliseconds: 1000);

  Timer? _timer;

  void jumpTo(int index) {
    final target = index.clamp(0, state.lastIndex);
    if (target == state.index) return;
    emit(state.copyWith(index: target));
    if (state.atEnd) _stop();
  }

  void next() => jumpTo(state.index + 1);
  void previous() => jumpTo(state.index - 1);
  void first() => jumpTo(0);
  void last() => jumpTo(state.lastIndex);

  void jumpToStreet(Street street) {
    final index = state.firstStepOf(street);
    if (index != null) jumpTo(index);
  }

  /// Plays from the current step, or from the start when at the end.
  void togglePlay() {
    if (state.playing) {
      _stop();
      return;
    }
    if (state.atEnd) emit(state.copyWith(index: 0));
    emit(state.copyWith(playing: true));
    _schedule();
  }

  void setSpeed(double speed) {
    emit(state.copyWith(speed: speed));
    if (state.playing) _schedule();
  }

  void setAmountsInBigBlinds(bool value) =>
      emit(state.copyWith(amountsInBigBlinds: value));

  void setHideOpponentCards(bool value) =>
      emit(state.copyWith(hideOpponentCards: value));

  void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(_stepInterval * (1 / state.speed), (_) => next());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (state.playing) emit(state.copyWith(playing: false));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
