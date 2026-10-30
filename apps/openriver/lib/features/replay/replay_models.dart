/// Presentation mirror of `crates/openriver_analytics/src/replay.rs`.
///
/// Every step is a complete table snapshot computed in Rust. The replay UI
/// renders these values as given and never derives pots, positions, turn
/// order, or legality. Generated bridge types map onto these classes in one
/// adapter, so keep them together in this file.
library;

enum Street { preflop, flop, turn, river, showdown }

enum Position {
  smallBlind,
  bigBlind,
  utg,
  utg1,
  utg2,
  utg3,
  lojack,
  hijack,
  cutoff,
  button,
}

enum Suit { clubs, diamonds, hearts, spades }

enum Rank {
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  ten,
  jack,
  queen,
  king,
  ace,
}

enum SeatStatus { active, folded, allIn }

final class PlayingCard {
  const PlayingCard(this.rank, this.suit);
  final Rank rank;
  final Suit suit;

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.rank == rank && other.suit == suit;

  @override
  int get hashCode => Object.hash(rank, suit);
}

/// One canonical action. Raise-to is the total street contribution.
sealed class ActionKind {
  const ActionKind();
}

final class PostSmallBlind extends ActionKind {
  const PostSmallBlind(this.amount);
  final int amount;
}

final class PostBigBlind extends ActionKind {
  const PostBigBlind(this.amount);
  final int amount;
}

final class PostAnte extends ActionKind {
  const PostAnte(this.amount);
  final int amount;
}

final class Fold extends ActionKind {
  const Fold();
}

final class Check extends ActionKind {
  const Check();
}

final class Call extends ActionKind {
  const Call(this.amount);
  final int amount;
}

final class Bet extends ActionKind {
  const Bet(this.amount);
  final int amount;
}

final class RaiseTo extends ActionKind {
  const RaiseTo(this.total);
  final int total;
}

final class ReturnUncalled extends ActionKind {
  const ReturnUncalled(this.amount);
  final int amount;
}

/// What changed between the previous step and this one.
sealed class ReplayEvent {
  const ReplayEvent();
}

/// Players seated with their starting stacks; nothing posted yet.
final class Start extends ReplayEvent {
  const Start();
}

final class ActionStep extends ReplayEvent {
  const ActionStep({
    required this.seq,
    required this.seat,
    required this.kind,
    this.allIn = false,
  });
  final int seq;
  final int seat;
  final ActionKind kind;
  final bool allIn;
}

/// Bets were collected and this street's cards were dealt.
final class StreetDealt extends ReplayEvent {
  const StreetDealt(this.street, this.cards);
  final Street street;
  final List<PlayingCard> cards;
}

/// Bets were collected and the remaining players reached showdown.
final class Showdown extends ReplayEvent {
  const Showdown();
}

/// Chips moved from a declared pot to a player.
final class AwardStep extends ReplayEvent {
  const AwardStep({
    required this.potIndex,
    required this.seat,
    required this.amount,
  });
  final int potIndex;
  final int seat;
  final int amount;
}

final class PotView {
  const PotView(this.amount, this.eligibleSeats);

  /// Gross amount before rake.
  final int amount;
  final List<int> eligibleSeats;
}

final class SeatView {
  const SeatView({
    required this.seat,
    required this.name,
    required this.stack,
    this.position,
    this.bet = 0,
    this.status = SeatStatus.active,
    this.lastAction,
    this.holeCards,
    this.won = 0,
  });

  final int seat;
  final String name;
  final Position? position;
  final int stack;

  /// Chips in front of the player on the current street, not yet collected.
  final int bet;
  final SeatStatus status;

  /// The player's latest action on this street, cleared when bets are
  /// collected.
  final ActionKind? lastAction;

  /// Exactly what the source reported: `null` when unreported, and a `null`
  /// entry for an unknown card.
  final List<PlayingCard?>? holeCards;

  /// Total awarded to this player so far.
  final int won;
}

final class ReplayStep {
  const ReplayStep({
    required this.event,
    required this.street,
    required this.board,
    required this.seats,
    required this.pot,
    this.pots = const [],
    this.nextToAct,
  });

  final ReplayEvent event;
  final Street street;

  /// Board cards dealt so far.
  final List<PlayingCard> board;

  /// Ordered by seat number.
  final List<SeatView> seats;

  /// Collected chips, excluding bets still in front of players.
  final int pot;

  /// Declared pots, present from the showdown or first award on.
  final List<PotView> pots;

  /// Seat that makes the next decision, when the next step is a decision.
  final int? nextToAct;

  /// Everything in the middle, including uncollected bets.
  int get totalPot => pot + seats.fold(0, (sum, seat) => sum + seat.bet);
}

final class Replay {
  const Replay({
    required this.currency,
    required this.currencyScale,
    required this.smallBlind,
    required this.bigBlind,
    required this.tableCapacity,
    required this.steps,
    this.ante = 0,
    this.buttonSeat,
  });

  final String currency;
  final int currencyScale;
  final int smallBlind;
  final int bigBlind;
  final int ante;

  /// Between 2 and 10.
  final int tableCapacity;

  /// `null` when the source did not say where the button was.
  final int? buttonSeat;
  final List<ReplayStep> steps;
}
