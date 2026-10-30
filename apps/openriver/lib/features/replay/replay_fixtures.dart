import 'replay_models.dart';

/// Hand-built replays for development and tests.
///
/// Real replays come from Rust. These are written out by hand: every stack,
/// bet, and pot below is a literal. [_HandBuilder] only copies the previous
/// snapshot forward, so each step does not repeat unchanged seats.
abstract final class ReplayFixtures {
  static final all = [sidePotAllIn, sixMaxRiver, nineHandedWalk, headsUp];

  /// Three-handed all-in with a side pot, matching
  /// `fixtures/hands/golden_side_pot.txt` in cents.
  static final sidePotAllIn = () {
    final hand = _HandBuilder([
      SeatView(
        seat: 1,
        name: 'Ada',
        position: Position.smallBlind,
        stack: 100,
        holeCards: [_c('As'), _c('Ah')],
      ),
      SeatView(
        seat: 2,
        name: 'Bo',
        position: Position.bigBlind,
        stack: 200,
        holeCards: [_c('Kc'), _c('Kd')],
      ),
      SeatView(
        seat: 3,
        name: 'Cy',
        position: Position.button,
        stack: 300,
        holeCards: [_c('Qs'), _c('Qh')],
      ),
    ]);
    hand
      ..act(1, const PostSmallBlind(1), stack: 99, bet: 1)
      ..act(2, const PostBigBlind(2), stack: 198, bet: 2)
      ..act(3, const RaiseTo(300), stack: 0, bet: 300, allIn: true)
      ..act(1, const Call(99), stack: 0, bet: 100, allIn: true)
      ..act(2, const Call(198), stack: 0, bet: 200, allIn: true)
      ..act(
        3,
        const ReturnUncalled(100),
        stack: 100,
        bet: 200,
        status: SeatStatus.active,
      )
      ..deal(Street.flop, ['2c', '7d', '9h'], pot: 500)
      ..deal(Street.turn, ['Js'], pot: 500)
      ..deal(Street.river, ['3c'], pot: 500)
      ..showdown(
        pot: 500,
        pots: const [
          PotView(300, [1, 2, 3]),
          PotView(200, [2, 3]),
        ],
      )
      ..award(0, 1, 300, pot: 200, stack: 300)
      ..award(1, 2, 200, pot: 0, stack: 200);
    return hand.build(
      currency: 'USD',
      currencyScale: 2,
      smallBlind: 1,
      bigBlind: 2,
      tableCapacity: 6,
      buttonSeat: 3,
    );
  }();

  /// Six-max single raised pot: a fold, a flop bet and raise, then a river
  /// bet called at showdown.
  static final sixMaxRiver = () {
    final hand = _HandBuilder([
      const SeatView(
        seat: 1,
        name: 'Uma',
        position: Position.utg,
        stack: 10000,
      ),
      SeatView(
        seat: 2,
        name: 'Hero',
        position: Position.hijack,
        stack: 10000,
        holeCards: [_c('Ad'), _c('Kc')],
      ),
      const SeatView(
        seat: 3,
        name: 'Cole',
        position: Position.cutoff,
        stack: 8450,
      ),
      const SeatView(
        seat: 4,
        name: 'Bea',
        position: Position.button,
        stack: 12230,
      ),
      const SeatView(
        seat: 5,
        name: 'Sam',
        position: Position.smallBlind,
        stack: 10000,
      ),
      SeatView(
        seat: 6,
        name: 'Bianca',
        position: Position.bigBlind,
        stack: 10000,
        holeCards: [_c('7h'), _c('7d')],
      ),
    ]);
    hand
      ..act(5, const PostSmallBlind(50), stack: 9950, bet: 50)
      ..act(6, const PostBigBlind(100), stack: 9900, bet: 100)
      ..act(1, const Fold(), stack: 10000, bet: 0)
      ..act(2, const RaiseTo(300), stack: 9700, bet: 300)
      ..act(3, const Fold(), stack: 8450, bet: 0)
      ..act(4, const Fold(), stack: 12230, bet: 0)
      ..act(5, const Fold(), stack: 9950, bet: 50)
      ..act(6, const Call(200), stack: 9700, bet: 300)
      ..deal(Street.flop, ['Ah', '7c', '2d'], pot: 650)
      ..act(6, const Check(), stack: 9700, bet: 0)
      ..act(2, const Bet(400), stack: 9300, bet: 400)
      ..act(6, const RaiseTo(1200), stack: 8500, bet: 1200)
      ..act(2, const Call(800), stack: 8500, bet: 1200)
      ..deal(Street.turn, ['Kd'], pot: 3050)
      ..act(6, const Check(), stack: 8500, bet: 0)
      ..act(2, const Check(), stack: 8500, bet: 0)
      ..deal(Street.river, ['5s'], pot: 3050)
      ..act(6, const Bet(2000), stack: 6500, bet: 2000)
      ..act(2, const Call(2000), stack: 6500, bet: 2000)
      ..showdown(
        pot: 7050,
        pots: const [
          PotView(7050, [2, 6]),
        ],
      )
      ..award(0, 6, 7050, pot: 0, stack: 13550);
    return hand.build(
      currency: 'USD',
      currencyScale: 2,
      smallBlind: 50,
      bigBlind: 100,
      tableCapacity: 6,
      buttonSeat: 4,
    );
  }();

  /// Nine-handed walk: everyone folds to the big blind.
  static final nineHandedWalk = () {
    const names = ['Ivo', 'Sia', 'Bram', 'Una', 'Hero', 'Tess', 'Lio', 'Hal'];
    const positions = [
      Position.button,
      Position.smallBlind,
      Position.bigBlind,
      Position.utg,
      Position.utg1,
      Position.utg2,
      Position.lojack,
      Position.hijack,
      Position.cutoff,
    ];
    final hand = _HandBuilder([
      for (var seat = 1; seat <= 9; seat++)
        SeatView(
          seat: seat,
          name: seat == 9 ? 'Cora' : names[seat - 1],
          position: positions[seat - 1],
          stack: 2000 + seat * 115,
          holeCards: seat == 5 ? [_c('9s'), _c('8s')] : null,
        ),
    ]);
    hand
      ..act(2, const PostSmallBlind(10), stack: 2220, bet: 10)
      ..act(3, const PostBigBlind(20), stack: 2325, bet: 20);
    for (final seat in [4, 5, 6, 7, 8, 9, 1]) {
      hand.act(seat, const Fold(), stack: 2000 + seat * 115, bet: 0);
    }
    hand
      ..act(2, const Fold(), stack: 2220, bet: 10)
      ..award(
        0,
        3,
        30,
        pot: 0,
        stack: 2355,
        pots: const [
          PotView(30, [3]),
        ],
      );
    return hand.build(
      currency: 'EUR',
      currencyScale: 2,
      smallBlind: 10,
      bigBlind: 20,
      tableCapacity: 9,
      buttonSeat: 1,
    );
  }();

  /// Heads-up: the button raises, bets the flop, and the big blind folds.
  static final headsUp = () {
    final hand = _HandBuilder([
      const SeatView(
        seat: 1,
        name: 'Rui',
        position: Position.button,
        stack: 1000,
        holeCards: [null, null],
      ),
      SeatView(
        seat: 2,
        name: 'Hero',
        position: Position.bigBlind,
        stack: 1000,
        holeCards: [_c('Jh'), _c('Tc')],
      ),
    ]);
    hand
      ..act(1, const PostSmallBlind(5), stack: 995, bet: 5)
      ..act(2, const PostBigBlind(10), stack: 990, bet: 10)
      ..act(1, const RaiseTo(30), stack: 970, bet: 30)
      ..act(2, const Call(20), stack: 970, bet: 30)
      ..deal(Street.flop, ['Qd', '6s', '3h'], pot: 60)
      ..act(2, const Check(), stack: 970, bet: 0)
      ..act(1, const Bet(30), stack: 940, bet: 30)
      ..act(2, const Fold(), stack: 970, bet: 0)
      ..act(1, const ReturnUncalled(30), stack: 970, bet: 0)
      ..award(
        0,
        1,
        60,
        pot: 0,
        stack: 1030,
        pots: const [
          PotView(60, [1, 2]),
        ],
      );
    return hand.build(
      currency: 'EUR',
      currencyScale: 2,
      smallBlind: 5,
      bigBlind: 10,
      tableCapacity: 2,
      buttonSeat: 1,
    );
  }();
}

/// Card from short notation such as `As` or `Td`.
PlayingCard _c(String code) => PlayingCard(
  Rank.values['23456789TJQKA'.indexOf(code[0])],
  switch (code[1]) {
    'c' => Suit.clubs,
    'd' => Suit.diamonds,
    'h' => Suit.hearts,
    _ => Suit.spades,
  },
);

/// Accumulates fixture steps from literal values. Each call copies the
/// previous snapshot and overrides what the caller states.
final class _HandBuilder {
  _HandBuilder(List<SeatView> seats) {
    _steps.add(
      ReplayStep(
        event: const Start(),
        street: Street.preflop,
        board: const [],
        seats: seats,
        pot: 0,
      ),
    );
  }

  final _steps = <ReplayStep>[];
  var _sequence = 0;

  ReplayStep get _last => _steps.last;

  void _push(
    ReplayEvent event, {
    Street? street,
    List<PlayingCard>? board,
    required List<SeatView> seats,
    int? pot,
    List<PotView>? pots,
  }) => _steps.add(
    ReplayStep(
      event: event,
      street: street ?? _last.street,
      board: board ?? _last.board,
      seats: seats,
      pot: pot ?? _last.pot,
      pots: pots ?? _last.pots,
    ),
  );

  /// A decision or forced post. [status] defaults to folded for a fold,
  /// all-in when [allIn], and otherwise the seat's current status.
  void act(
    int seat,
    ActionKind kind, {
    required int stack,
    required int bet,
    bool allIn = false,
    SeatStatus? status,
  }) {
    _push(
      ActionStep(seq: ++_sequence, seat: seat, kind: kind, allIn: allIn),
      seats: [
        for (final view in _last.seats)
          view.seat != seat
              ? view
              : _copy(
                  view,
                  stack: stack,
                  bet: bet,
                  status:
                      status ??
                      (kind is Fold
                          ? SeatStatus.folded
                          : allIn
                          ? SeatStatus.allIn
                          : view.status),
                  // Returned chips keep the action that put them out.
                  lastAction: kind is ReturnUncalled ? view.lastAction : kind,
                ),
      ],
    );
  }

  List<SeatView> get _collected => [
    for (final view in _last.seats) _copy(view, bet: 0, clearAction: true),
  ];

  void deal(Street street, List<String> cards, {required int pot}) {
    final dealt = cards.map(_c).toList();
    _push(
      StreetDealt(street, dealt),
      street: street,
      board: [..._last.board, ...dealt],
      seats: _collected,
      pot: pot,
    );
  }

  void showdown({required int pot, required List<PotView> pots}) => _push(
    const Showdown(),
    street: Street.showdown,
    seats: _collected,
    pot: pot,
    pots: pots,
  );

  void award(
    int potIndex,
    int seat,
    int amount, {
    required int pot,
    required int stack,
    List<PotView>? pots,
  }) => _push(
    AwardStep(potIndex: potIndex, seat: seat, amount: amount),
    seats: [
      for (final view in _collected)
        view.seat != seat
            ? view
            : _copy(view, stack: stack, won: view.won + amount),
    ],
    pot: pot,
    pots: pots,
  );

  Replay build({
    required String currency,
    required int currencyScale,
    required int smallBlind,
    required int bigBlind,
    required int tableCapacity,
    int? buttonSeat,
  }) => Replay(
    currency: currency,
    currencyScale: currencyScale,
    smallBlind: smallBlind,
    bigBlind: bigBlind,
    tableCapacity: tableCapacity,
    buttonSeat: buttonSeat,
    steps: [
      for (var i = 0; i < _steps.length; i++)
        _withNextToAct(
          _steps[i],
          i + 1 < _steps.length ? _steps[i + 1].event : null,
        ),
    ],
  );

  /// Mirrors replay.rs: a step names the seat whose decision comes next.
  static ReplayStep _withNextToAct(ReplayStep step, ReplayEvent? next) {
    final decision =
        next is ActionStep &&
        next.kind is! PostSmallBlind &&
        next.kind is! PostBigBlind &&
        next.kind is! PostAnte &&
        next.kind is! ReturnUncalled;
    return ReplayStep(
      event: step.event,
      street: step.street,
      board: step.board,
      seats: step.seats,
      pot: step.pot,
      pots: step.pots,
      nextToAct: decision ? next.seat : null,
    );
  }

  static SeatView _copy(
    SeatView view, {
    int? stack,
    int? bet,
    SeatStatus? status,
    ActionKind? lastAction,
    bool clearAction = false,
    int? won,
  }) => SeatView(
    seat: view.seat,
    name: view.name,
    position: view.position,
    stack: stack ?? view.stack,
    bet: bet ?? view.bet,
    status: status ?? view.status,
    lastAction: clearAction ? null : (lastAction ?? view.lastAction),
    holeCards: view.holeCards,
    won: won ?? view.won,
  );
}
