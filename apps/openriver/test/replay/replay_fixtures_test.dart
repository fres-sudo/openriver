import 'package:flutter_test/flutter_test.dart';
import 'package:openriver/features/replay/replay_fixtures.dart';
import 'package:openriver/features/replay/replay_models.dart';

/// The fixtures are typed by hand, so check the facts replay.rs guarantees.
void main() {
  for (final (index, replay) in ReplayFixtures.all.indexed) {
    test('fixture $index keeps every chip on the table', () {
      final steps = replay.steps;
      int onTable(ReplayStep step) =>
          step.totalPot + step.seats.fold(0, (sum, seat) => sum + seat.stack);
      final starting = onTable(steps.first);
      expect(steps.first.event, isA<Start>());
      for (final step in steps) {
        expect(onTable(step), starting, reason: '${step.event}');
        expect(step.seats.every((s) => s.stack >= 0 && s.bet >= 0), isTrue);
        expect(
          step.seats.map((s) => s.seat).toList(),
          [...step.seats.map((s) => s.seat)]..sort(),
        );
        expect(step.seats.length, lessThanOrEqualTo(replay.tableCapacity));
      }
      expect(steps.last.totalPot, 0, reason: 'no rake in the fixtures');
      final won = steps.last.seats.fold(0, (sum, seat) => sum + seat.won);
      final awarded = steps
          .map((s) => s.event)
          .whereType<AwardStep>()
          .fold(0, (sum, award) => sum + award.amount);
      expect(won, awarded);
    });
  }

  test('the side-pot fixture matches the Rust golden replay', () {
    final steps = ReplayFixtures.sidePotAllIn.steps;
    expect(steps, hasLength(13));
    expect(steps[2].nextToAct, 3);
    expect(steps[3].nextToAct, 1);
    expect(steps[5].nextToAct, isNull);
    expect(steps[6].totalPot, 500);
    expect(steps[6].seats[2].status, SeatStatus.active);
    expect(steps[6].seats[2].lastAction, isA<RaiseTo>());
    expect(steps[9].pots, isEmpty);
    expect(steps[10].street, Street.showdown);
    expect(steps[10].pots, hasLength(2));
  });
}
