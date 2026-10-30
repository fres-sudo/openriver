import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openriver/features/replay/replay_fixtures.dart';
import 'package:openriver/features/replay/replay_models.dart';

import 'replay_harness.dart';

/// Ten seated players, every one with a bet out, to crowd the table.
final _tenHanded = Replay(
  currency: 'USD',
  currencyScale: 2,
  smallBlind: 5000,
  bigBlind: 10000,
  tableCapacity: 10,
  buttonSeat: 10,
  steps: [
    for (final event in const [Start(), Showdown()])
      ReplayStep(
        event: event,
        street: event is Start ? Street.preflop : Street.showdown,
        board: event is Start
            ? const []
            : const [
                PlayingCard(Rank.ten, Suit.hearts),
                PlayingCard(Rank.ten, Suit.spades),
                PlayingCard(Rank.queen, Suit.diamonds),
                PlayingCard(Rank.two, Suit.clubs),
                PlayingCard(Rank.ace, Suit.hearts),
              ],
        pot: event is Start ? 0 : 123456789,
        pots: event is Start
            ? const []
            : const [
                PotView(100000000, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
                PotView(20000000, [1, 2]),
                PotView(3456789, [1, 2]),
              ],
        nextToAct: event is Start ? 4 : null,
        seats: [
          for (var seat = 1; seat <= 10; seat++)
            SeatView(
              seat: seat,
              name: 'A rather long player name $seat',
              position: Position.values[seat - 1],
              stack: 987654321,
              bet: event is Start ? 12345678 : 0,
              status: SeatStatus.values[seat % 3],
              lastAction: event is Start ? const RaiseTo(12345678) : null,
              holeCards: seat.isEven
                  ? const [
                      PlayingCard(Rank.ten, Suit.diamonds),
                      PlayingCard(Rank.ace, Suit.clubs),
                    ]
                  : const [PlayingCard(Rank.king, Suit.hearts), null],
              won: event is Start ? 0 : 1000000,
            ),
        ],
      ),
  ],
);

void main() {
  final tables = {
    2: ReplayFixtures.headsUp,
    3: ReplayFixtures.sidePotAllIn,
    6: ReplayFixtures.sixMaxRiver,
    9: ReplayFixtures.nineHandedWalk,
    10: _tenHanded,
  };
  const sizes = [
    Size(360, 740),
    Size(390, 844),
    Size(800, 1000),
    Size(1600, 1000),
  ];

  for (final MapEntry(key: players, value: replay) in tables.entries) {
    for (final size in sizes) {
      for (final textScale in [1.0, 2.0]) {
        for (final brightness in Brightness.values) {
          final name =
              '$players players at ${size.width.toInt()} px, '
              '${textScale}x, ${brightness.name}';
          testWidgets('$name renders every step without overflow', (
            tester,
          ) async {
            final cubit = await pumpReplay(
              tester,
              replay,
              size: size,
              textScale: textScale,
              brightness: brightness,
            );
            expect(tester.takeException(), isNull);
            for (var index = 1; index < replay.steps.length; index++) {
              cubit.jumpTo(index);
              await tester.pump();
              expect(tester.takeException(), isNull, reason: 'step $index');
            }
            final table = tester.getRect(find.byKey(const ValueKey('seat-1')));
            expect(table.left, greaterThanOrEqualTo(0));
            expect(table.right, lessThanOrEqualTo(size.width));
          });
        }
      }
    }
  }
}
