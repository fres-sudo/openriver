import 'package:flutter_test/flutter_test.dart';
import 'package:openriver/features/replay/replay_fixtures.dart';
import 'package:openriver/features/replay/replay_format.dart';
import 'package:openriver/features/replay/replay_models.dart';
import 'package:openriver/l10n/generated/app_localizations_en.dart';

void main() {
  final strings = AppLocalizationsEn();
  final replay = ReplayFixtures.sidePotAllIn;
  final money = ReplayFormat(replay, strings);
  final blinds = ReplayFormat(replay, strings, inBigBlinds: true);

  test('formats chips in the currency scale or in big blinds', () {
    expect(money.amount(150), r'$1.50');
    expect(money.amount(0), r'$0.00');
    expect(money.amount(7), r'$0.07');
    expect(money.amount(123456789), r'$1,234,567.89');
    expect(blinds.amount(15), '7.5 BB');
    expect(blinds.amount(300), '150 BB');
    expect(blinds.amount(1), '0.5 BB');
    const chips = Replay(
      currency: '',
      currencyScale: 0,
      smallBlind: 25,
      bigBlind: 50,
      tableCapacity: 9,
      steps: [],
    );
    expect(ReplayFormat(chips, strings).amount(12500), '12,500');
    const cad = Replay(
      currency: 'CAD',
      currencyScale: 2,
      smallBlind: 1,
      bigBlind: 2,
      tableCapacity: 6,
      steps: [],
    );
    expect(ReplayFormat(cad, strings).amount(150), '1.50 CAD');
  });

  test('describes every event in words', () {
    final steps = replay.steps;
    expect(money.describe(steps[0]), r'3 players seated, blinds $0.01/$0.02');
    expect(money.describe(steps[1]), r'Ada posts small blind $0.01');
    expect(money.describe(steps[3]), r'Cy raises to $3.00, all-in');
    expect(money.describe(steps[6]), r'Cy takes back $1.00 uncalled');
    expect(
      money.describe(steps[7]),
      'Flop: 2 of clubs, 7 of diamonds, 9 of hearts',
    );
    expect(money.describe(steps[10]), 'Showdown');
    expect(money.describe(steps[12]), r'Bo wins $2.00 from the side pot 1');
    expect(money.actionLabel(const RaiseTo(300)), r'Raise to $3.00');
    expect(blinds.actionLabel(const Call(99)), 'Call 49.5 BB');
  });
}
