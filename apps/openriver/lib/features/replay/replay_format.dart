import '../../l10n/generated/app_localizations.dart';
import 'replay_models.dart';

/// Turns replay values into display text. Amounts are integer chips in the
/// smallest currency unit; this is the only place they become strings.
final class ReplayFormat {
  const ReplayFormat(this.replay, this.strings, {this.inBigBlinds = false});

  final Replay replay;
  final AppLocalizations strings;
  final bool inBigBlinds;

  static const _symbols = {'USD': r'$', 'EUR': '€', 'GBP': '£'};

  /// `$1.50`, `1.50 CAD`, or `7.5 BB` when [inBigBlinds] is set.
  String amount(int chips) {
    if (inBigBlinds && replay.bigBlind > 0) {
      final blinds = (chips / replay.bigBlind)
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'\.?0+$'), '');
      return strings.amountInBigBlinds(blinds);
    }
    final scale = replay.currencyScale;
    final sign = chips < 0 ? '-' : '';
    final digits = chips.abs().toString().padLeft(scale + 1, '0');
    final whole = _group(digits.substring(0, digits.length - scale));
    final fraction = scale == 0
        ? ''
        : '.${digits.substring(digits.length - scale)}';
    final symbol = _symbols[replay.currency];
    if (symbol != null) return '$sign$symbol$whole$fraction';
    final number = '$sign$whole$fraction';
    return replay.currency.isEmpty ? number : '$number ${replay.currency}';
  }

  static String _group(String whole) {
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
      buffer.write(whole[i]);
    }
    return buffer.toString();
  }

  /// Short label shown under a seat, such as "Raise to $3.00".
  String actionLabel(ActionKind kind) => switch (kind) {
    PostSmallBlind(:final amount) => strings.actionSmallBlind(
      this.amount(amount),
    ),
    PostBigBlind(:final amount) => strings.actionBigBlind(this.amount(amount)),
    PostAnte(:final amount) => strings.actionAnte(this.amount(amount)),
    Fold() => strings.actionFold,
    Check() => strings.actionCheck,
    Call(:final amount) => strings.actionCall(this.amount(amount)),
    Bet(:final amount) => strings.actionBet(this.amount(amount)),
    RaiseTo(:final total) => strings.actionRaiseTo(amount(total)),
    ReturnUncalled(:final amount) => strings.actionReturned(
      this.amount(amount),
    ),
  };

  String seatName(ReplayStep step, int seat) {
    for (final view in step.seats) {
      if (view.seat == seat) return view.name;
    }
    return strings.seatFallbackName(seat);
  }

  /// The step's event in words, such as "Cy raises to $3.00, all-in".
  String describe(ReplayStep step) => switch (step.event) {
    Start() => strings.eventStart(
      step.seats.length,
      amount(replay.smallBlind),
      amount(replay.bigBlind),
    ),
    ActionStep(:final seat, :final kind, allIn: false) => _describeAction(
      seatName(step, seat),
      kind,
    ),
    ActionStep(:final seat, :final kind, allIn: true) => strings.eventAllIn(
      _describeAction(seatName(step, seat), kind),
    ),
    StreetDealt(:final street, :final cards) =>
      cards.isEmpty
          ? strings.eventStreetNoCards(streetName(street))
          : strings.eventStreet(
              streetName(street),
              cards.map(cardName).join(', '),
            ),
    Showdown() => strings.eventShowdown,
    AwardStep(:final potIndex, :final seat, :final amount) =>
      strings.eventAward(
        seatName(step, seat),
        this.amount(amount),
        potIndex == 0 ? strings.potMain : strings.potSide(potIndex),
      ),
  };

  String _describeAction(String name, ActionKind kind) => switch (kind) {
    PostSmallBlind(:final amount) => strings.eventSmallBlind(
      name,
      this.amount(amount),
    ),
    PostBigBlind(:final amount) => strings.eventBigBlind(
      name,
      this.amount(amount),
    ),
    PostAnte(:final amount) => strings.eventAnte(name, this.amount(amount)),
    Fold() => strings.eventFold(name),
    Check() => strings.eventCheck(name),
    Call(:final amount) => strings.eventCall(name, this.amount(amount)),
    Bet(:final amount) => strings.eventBet(name, this.amount(amount)),
    RaiseTo(:final total) => strings.eventRaiseTo(name, amount(total)),
    ReturnUncalled(:final amount) => strings.eventReturned(
      name,
      this.amount(amount),
    ),
  };

  String potShortName(int index) =>
      index == 0 ? strings.potMainShort : strings.potSideShort(index);

  String streetName(Street street) => switch (street) {
    Street.preflop => strings.streetPreflop,
    Street.flop => strings.streetFlop,
    Street.turn => strings.streetTurn,
    Street.river => strings.streetRiver,
    Street.showdown => strings.streetShowdown,
  };

  String positionBadge(Position position) => switch (position) {
    Position.smallBlind => strings.positionSmallBlindShort,
    Position.bigBlind => strings.positionBigBlindShort,
    Position.utg => strings.positionUtgShort,
    Position.utg1 => strings.positionUtg1Short,
    Position.utg2 => strings.positionUtg2Short,
    Position.utg3 => strings.positionUtg3Short,
    Position.lojack => strings.positionLojackShort,
    Position.hijack => strings.positionHijackShort,
    Position.cutoff => strings.positionCutoffShort,
    Position.button => strings.positionButtonShort,
  };

  String positionName(Position position) => switch (position) {
    Position.smallBlind => strings.positionSmallBlind,
    Position.bigBlind => strings.positionBigBlind,
    Position.utg => strings.positionUtg,
    Position.utg1 => strings.positionUtg1,
    Position.utg2 => strings.positionUtg2,
    Position.utg3 => strings.positionUtg3,
    Position.lojack => strings.positionLojack,
    Position.hijack => strings.positionHijack,
    Position.cutoff => strings.positionCutoff,
    Position.button => strings.positionButton,
  };

  /// Rank glyph printed on a card. Ranks and suit glyphs are notation, not
  /// language, so they are not localized.
  static String rankSymbol(Rank rank) => switch (rank) {
    Rank.two => '2',
    Rank.three => '3',
    Rank.four => '4',
    Rank.five => '5',
    Rank.six => '6',
    Rank.seven => '7',
    Rank.eight => '8',
    Rank.nine => '9',
    Rank.ten => '10',
    Rank.jack => 'J',
    Rank.queen => 'Q',
    Rank.king => 'K',
    Rank.ace => 'A',
  };

  static String suitSymbol(Suit suit) => switch (suit) {
    Suit.clubs => '♣',
    Suit.diamonds => '♦',
    Suit.hearts => '♥',
    Suit.spades => '♠',
  };

  /// Spoken card name, such as "ace of spades".
  String cardName(PlayingCard card) {
    final rank = switch (card.rank) {
      Rank.jack => strings.rankJack,
      Rank.queen => strings.rankQueen,
      Rank.king => strings.rankKing,
      Rank.ace => strings.rankAce,
      _ => rankSymbol(card.rank),
    };
    return switch (card.suit) {
      Suit.clubs => strings.cardClubs(rank),
      Suit.diamonds => strings.cardDiamonds(rank),
      Suit.hearts => strings.cardHearts(rank),
      Suit.spades => strings.cardSpades(rank),
    };
  }
}
