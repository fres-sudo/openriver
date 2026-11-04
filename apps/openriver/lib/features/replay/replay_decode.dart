import 'dart:convert';

import 'replay_models.dart';

/// Decode snapshots produced by Rust's validated replay engine.
Replay decodeReplay(String source) {
  final data = jsonDecode(source) as Map<String, dynamic>;
  return Replay(
    currency: data['currency'] as String,
    currencyScale: data['currency_scale'] as int,
    smallBlind: data['small_blind'] as int,
    bigBlind: data['big_blind'] as int,
    ante: data['ante'] as int,
    tableCapacity: data['table_capacity'] as int,
    buttonSeat: data['button_seat'] as int?,
    steps: [
      for (final raw in data['steps'] as List)
        _step(raw as Map<String, dynamic>),
    ],
  );
}

ReplayStep _step(Map<String, dynamic> data) => ReplayStep(
  event: _event(data['event']),
  street: _street(data['street'] as String),
  board: [
    for (final raw in data['board'] as List) _card(raw as Map<String, dynamic>),
  ],
  seats: [
    for (final raw in data['seats'] as List) _seat(raw as Map<String, dynamic>),
  ],
  pot: data['pot'] as int,
  pots: [
    for (final raw in data['pots'] as List)
      PotView((raw as Map<String, dynamic>)['amount'] as int, [
        for (final seat in raw['eligible_seats'] as List) seat as int,
      ]),
  ],
  nextToAct: data['next_to_act'] as int?,
);

SeatView _seat(Map<String, dynamic> data) => SeatView(
  seat: data['seat'] as int,
  name: data['name'] as String,
  position: data['position'] == null
      ? null
      : Position.values.byName(_camel(data['position'] as String)),
  stack: data['stack'] as int,
  bet: data['bet'] as int,
  status: SeatStatus.values.byName(_camel(data['status'] as String)),
  lastAction: data['last_action'] == null ? null : _action(data['last_action']),
  holeCards: data['hole_cards'] == null
      ? null
      : [
          for (final raw in data['hole_cards'] as List)
            raw == null ? null : _card(raw as Map<String, dynamic>),
        ],
  won: data['won'] as int,
);

PlayingCard _card(Map<String, dynamic> data) => PlayingCard(
  Rank.values.byName(_camel(data['rank'] as String)),
  Suit.values.byName(_camel(data['suit'] as String)),
);

ReplayEvent _event(Object? raw) {
  if (raw == 'Start') return const Start();
  if (raw == 'Showdown') return const Showdown();
  final entry = (raw as Map<String, dynamic>).entries.single;
  final data = entry.value as Map<String, dynamic>;
  return switch (entry.key) {
    'Action' => ActionStep(
      seq: data['sequence'] as int,
      seat: data['seat'] as int,
      kind: _action(data['kind']),
      allIn: data['all_in'] as bool,
    ),
    'Street' => StreetDealt(_street(data['street'] as String), [
      for (final raw in data['cards'] as List)
        _card(raw as Map<String, dynamic>),
    ]),
    'Award' => AwardStep(
      potIndex: data['pot_index'] as int,
      seat: data['seat'] as int,
      amount: data['amount'] as int,
    ),
    _ => throw FormatException('Unknown replay event ${entry.key}'),
  };
}

ActionKind _action(Object? raw) {
  if (raw == 'Fold') return const Fold();
  if (raw == 'Check') return const Check();
  final entry = (raw as Map<String, dynamic>).entries.single;
  final data = entry.value as Map<String, dynamic>;
  return switch (entry.key) {
    'PostSmallBlind' => PostSmallBlind(data['amount_added'] as int),
    'PostBigBlind' => PostBigBlind(data['amount_added'] as int),
    'PostAnte' => PostAnte(data['amount_added'] as int),
    'Call' => Call(data['amount_added'] as int),
    'Bet' => Bet(data['amount_added'] as int),
    'RaiseTo' => RaiseTo(data['total_street_contribution'] as int),
    'ReturnUncalled' => ReturnUncalled(data['amount'] as int),
    _ => throw FormatException('Unknown action ${entry.key}'),
  };
}

Street _street(String name) => Street.values.byName(_camel(name));
String _camel(String name) => '${name[0].toLowerCase()}${name.substring(1)}';
