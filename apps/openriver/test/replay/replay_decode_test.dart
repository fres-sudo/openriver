import 'package:flutter_test/flutter_test.dart';
import 'package:openriver/features/replay/replay_decode.dart';
import 'package:openriver/features/replay/replay_models.dart';

// Matches serde's wire shape for the Rust replay snapshot types.
import 'replay_wire_fixture.dart';

void main() {
  test('decodes Rust replay events and unknown cards', () {
    final replay = decodeReplay(replayJson);
    expect(replay.currencyScale, 2);
    expect(replay.buttonSeat, 1);
    expect(replay.steps, hasLength(4));
    expect(replay.steps.first.seats.first.position, Position.smallBlind);
    expect(replay.steps.first.seats.first.holeCards, [
      const PlayingCard(Rank.ace, Suit.spades),
      null,
    ]);
    expect(replay.steps[1].event, isA<ActionStep>());
    expect((replay.steps[1].event as ActionStep).kind, isA<PostSmallBlind>());
    expect(replay.steps[2].event, isA<StreetDealt>());
    expect(replay.steps[2].board, [const PlayingCard(Rank.two, Suit.clubs)]);
    expect(replay.steps[3].event, isA<AwardStep>());
    expect(replay.steps[3].pots.single.eligibleSeats, [1, 2]);
  });
}
