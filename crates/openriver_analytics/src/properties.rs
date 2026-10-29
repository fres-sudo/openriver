//! Property tests over randomly played hands. Each failing case shrinks to a
//! short entropy string that replays the same hand.

use crate::testkit::{simulate, Entropy, Setup};
use openriver_domain::Hand;
use proptest::prelude::*;

/// Derive a table setup, then a full hand, from raw entropy.
pub fn random_hand(bytes: &[u8]) -> Hand {
    let mut entropy = Entropy::new(bytes);
    let players = 2 + entropy.below(8) as usize;
    let mut seats: Vec<u8> = (1..=10).collect();
    for i in (1..seats.len()).rev() {
        let j = entropy.below(i as u32 + 1) as usize;
        seats.swap(i, j);
    }
    seats.truncate(players);
    let small_blind = 1 + i64::from(entropy.below(50));
    let big_blind = small_blind * 2;
    let ante = if entropy.below(4) == 0 {
        i64::from(entropy.below(small_blind as u32 + 1))
    } else {
        0
    };
    let seats = seats
        .into_iter()
        .map(|seat| {
            let stack = match entropy.below(4) {
                0 => 1 + i64::from(entropy.below(big_blind as u32 * 3)),
                1 => big_blind * (20 + i64::from(entropy.below(80))),
                _ => big_blind * (50 + i64::from(entropy.below(250))),
            };
            (seat, stack.max(ante + 1))
        })
        .collect();
    let setup = Setup {
        seats,
        button: 1 + entropy.below(10) as u8,
        capacity: 10,
        small_blind,
        big_blind,
        ante,
    };
    simulate(&setup, &mut entropy)
}

fn entropy_strategy() -> impl Strategy<Value = Vec<u8>> {
    proptest::collection::vec(any::<u8>(), 64..600)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(1000))]

    /// The simulator itself only ever produces hands the canonical validator accepts.
    #[test]
    fn simulated_hands_are_valid(bytes in proptest::collection::vec(any::<u8>(), 64..600)) {
        let hand = random_hand(&bytes);
        prop_assert!(openriver_domain::validate_hand(&hand).is_ok());
    }
}

/// Deterministic pseudo-random bytes for coverage checks.
pub fn bytes_for(seed: u64) -> Vec<u8> {
    let mut state = seed.wrapping_mul(0x9E37_79B9_7F4A_7C15) | 1;
    (0..400)
        .map(|_| {
            state ^= state << 13;
            state ^= state >> 7;
            state ^= state << 17;
            (state >> 24) as u8
        })
        .collect()
}

#[test]
fn simulator_reaches_the_situations_statistics_care_about() {
    use openriver_domain::{ActionKind, Street};
    let mut seen = [0usize; 8];
    let total = 3000;
    for seed in 0..total {
        let hand = random_hand(&bytes_for(seed as u64));
        let flop = hand.board.iter().any(|b| b.street == Street::Flop);
        let river = hand.board.iter().any(|b| b.street == Street::River);
        let all_in = hand.actions.iter().any(|a| a.all_in);
        let raises = hand
            .actions
            .iter()
            .filter(|a| matches!(a.kind, ActionKind::RaiseTo { .. }))
            .count();
        let returned = hand
            .actions
            .iter()
            .any(|a| matches!(a.kind, ActionKind::ReturnUncalled { .. }));
        for (slot, hit) in [
            flop,
            river,
            all_in,
            hand.pots.len() > 1,
            raises >= 2,
            raises >= 3,
            returned,
            hand.awards.iter().any(|a| {
                hand.awards
                    .iter()
                    .any(|b| b.pot_index == a.pot_index && b.seat != a.seat)
            }),
        ]
        .into_iter()
        .enumerate()
        {
            seen[slot] += usize::from(hit);
        }
    }
    let names = [
        "flop",
        "river",
        "all-in",
        "side pot",
        "3-bet+",
        "4-bet+",
        "returned",
        "split pot",
    ];
    for (name, count) in names.iter().zip(seen) {
        eprintln!("{name}: {count}/{total}");
        assert!(count * 100 >= total, "{name} appears in under 1% of hands");
    }
}

use crate::aggregate::{HandFilter, PlayerStats, StatsEngine};
use crate::analysis::{analyze, Act, HandAnalysis};
use crate::position::{Position, PositionGroup};
use crate::stats::Stat;
use openriver_domain::{ActionKind, Street};
use std::collections::BTreeSet;

type StatOutcomes = Vec<(Stat, Option<bool>)>;

fn outcomes(analysis: &HandAnalysis) -> Vec<(u8, StatOutcomes)> {
    analysis
        .players
        .iter()
        .map(|p| {
            (
                p.seat,
                Stat::ALL
                    .iter()
                    .map(|s| (*s, s.evaluate(analysis, p)))
                    .collect(),
            )
        })
        .collect()
}

fn get(list: &[(Stat, Option<bool>)], stat: Stat) -> Option<bool> {
    list.iter().find(|(s, _)| *s == stat).unwrap().1
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(1000))]

    #[test]
    fn chips_are_conserved_and_decisions_are_well_formed(bytes in entropy_strategy()) {
        let hand = random_hand(&bytes);
        let a = analyze(&hand).unwrap();
        // Everything invested is either won back or raked.
        let invested: i64 = a.players.iter().map(|p| p.invested).sum();
        let collected: i64 = a.players.iter().map(|p| p.collected).sum();
        prop_assert_eq!(invested, collected + hand.rake.0);
        prop_assert_eq!(a.players.iter().map(|p| p.net).sum::<i64>(), -hand.rake.0);
        for p in &a.players {
            prop_assert!(p.invested >= 0 && p.invested <= p.starting_stack);
            prop_assert_eq!(p.net, p.collected - p.invested);
        }
        let non_decisions = hand.actions.iter().filter(|e| matches!(e.kind,
            ActionKind::PostSmallBlind{..} | ActionKind::PostBigBlind{..}
            | ActionKind::PostAnte{..} | ActionKind::ReturnUncalled{..})).count();
        prop_assert_eq!(a.decisions.len() + non_decisions, hand.actions.len());
        let mut seen_first = BTreeSet::new();
        let mut folded = BTreeSet::new();
        for d in &a.decisions {
            prop_assert!(d.to_call >= 0 && d.stack_behind >= 0 && d.pot_before >= 0);
            prop_assert!(!folded.contains(&d.seat), "acted after folding");
            prop_assert_eq!(d.first_decision_of_hand, seen_first.insert(d.seat));
            match d.act {
                Act::Check => prop_assert_eq!(d.to_call, 0),
                Act::Call => prop_assert!(d.to_call > 0),
                Act::Bet => prop_assert!(d.street != Street::Preflop && d.bet_level_before == 0),
                Act::Raise => prop_assert!(d.bet_level_before >= 1),
                Act::Fold => { folded.insert(d.seat); }
            }
            prop_assert!(d.live_opponents >= d.opponents_with_chips);
            prop_assert!(d.live_opponents >= 1);
            if d.street == Street::Preflop { prop_assert!(d.bet_level_before >= 1); }
        }
        // Bet level never decreases within a street.
        for street in [Street::Preflop, Street::Flop, Street::Turn, Street::River] {
            let levels: Vec<u8> = a.street_decisions(street).map(|d| d.bet_level_before).collect();
            prop_assert!(levels.windows(2).all(|w| w[0] <= w[1]));
        }
    }

    #[test]
    fn positions_are_consistent(bytes in entropy_strategy()) {
        let hand = random_hand(&bytes);
        let a = analyze(&hand).unwrap();
        let positions: Vec<Position> = a.players.iter().map(|p| p.position.unwrap()).collect();
        prop_assert!(positions.iter().filter(|p| **p == Position::BigBlind).count() == 1);
        prop_assert!(positions.iter().filter(|p| **p == Position::Button).count() <= 1);
        if a.players.len() > 2 {
            prop_assert_eq!(positions.iter().filter(|p| **p == Position::SmallBlind).count(), 1);
            let distinct: BTreeSet<_> = positions.iter().collect();
            // Early labels are unique except where the table is too small to name them.
            prop_assert_eq!(distinct.len(), positions.len());
        }
        // The blind positions belong to the players who posted blinds.
        for p in &a.players {
            let blind = matches!(p.position, Some(Position::SmallBlind | Position::BigBlind));
            if a.players.len() > 2 { prop_assert_eq!(blind, p.posted_blind); }
        }
    }

    #[test]
    fn stat_outcomes_obey_logical_implications(bytes in entropy_strategy()) {
        let hand = random_hand(&bytes);
        let a = analyze(&hand).unwrap();
        let mut rfi_taken = 0;
        let mut cbet_eligible = 0;
        for (seat, o) in outcomes(&a) {
            let p = a.player(seat).unwrap();
            let taken = |s| get(&o, s) == Some(true);
            let eligible = |s| get(&o, s).is_some();
            // Dealt-in stats always apply.
            prop_assert!(eligible(Stat::Vpip) && eligible(Stat::Pfr) && eligible(Stat::SawFlop));
            // Raising preflop is voluntary.
            prop_assert!(!taken(Stat::Pfr) || taken(Stat::Vpip));
            for s in [Stat::RaiseFirstIn, Stat::StealAttempt, Stat::ThreeBet, Stat::FourBet] {
                prop_assert!(!taken(s) || taken(Stat::Pfr), "{:?} taken without PFR", s);
            }
            // A limp can be followed by a re-raise, so only VPIP is implied.
            prop_assert!(!taken(Stat::OpenLimp) || taken(Stat::Vpip));
            prop_assert_eq!(eligible(Stat::OpenLimp), eligible(Stat::RaiseFirstIn));
            prop_assert!(!(taken(Stat::OpenLimp) && taken(Stat::RaiseFirstIn)));
            prop_assert!(!eligible(Stat::StealAttempt) || eligible(Stat::RaiseFirstIn));
            prop_assert!(!taken(Stat::StealAttempt) || taken(Stat::RaiseFirstIn));
            prop_assert!(!taken(Stat::ColdCall) || taken(Stat::Vpip));
            prop_assert!(!eligible(Stat::ColdCall) || !p.posted_blind);
            prop_assert!(!eligible(Stat::FoldToThreeBet) || taken(Stat::Pfr));
            prop_assert!(!eligible(Stat::FoldToFourBet) || taken(Stat::Pfr));
            // Postflop stats need the flop.
            prop_assert_eq!(taken(Stat::SawFlop), p.saw_flop);
            prop_assert!(!p.saw_flop || p.folded_on != Some(Street::Preflop));
            for s in [Stat::CBetFlop, Stat::FoldToCBetFlop, Stat::CheckRaiseFlop,
                      Stat::WentToShowdown, Stat::WonWhenSawFlop] {
                prop_assert!(!eligible(s) || p.saw_flop, "{:?} without flop", s);
            }
            prop_assert!(!eligible(Stat::CBetTurn) || (get(&o, Stat::CBetFlop) == Some(true) && p.saw_turn));
            prop_assert!(!eligible(Stat::CBetFlop) || a.preflop_aggressor == Some(seat));
            prop_assert!(!eligible(Stat::FoldToCBetFlop) || a.preflop_aggressor != Some(seat));
            prop_assert_eq!(eligible(Stat::WonAtShowdown), p.went_to_showdown);
            prop_assert!(!taken(Stat::WonAtShowdown) || p.collected > 0);
            prop_assert!(!eligible(Stat::FoldSmallBlindToSteal) || p.position == Some(Position::SmallBlind));
            prop_assert!(!eligible(Stat::FoldBigBlindToSteal) || p.position == Some(Position::BigBlind));
            prop_assert!(!eligible(Stat::ThreeBetVsSteal) || p.posted_blind);
            rfi_taken += usize::from(taken(Stat::RaiseFirstIn));
            cbet_eligible += usize::from(eligible(Stat::CBetFlop));
        }
        prop_assert!(rfi_taken <= 1, "two players cannot both raise first in");
        prop_assert!(cbet_eligible <= 1);
        // Preflop aggressor exists exactly when someone raised preflop.
        let anyone_raised = a.decisions.iter().any(|d| d.street == Street::Preflop && d.act == Act::Raise);
        prop_assert_eq!(a.preflop_aggressor.is_some(), anyone_raised);
        // A steal can only be defended against if exactly one steal raise stands uncalled.
        let defenders = a.players.iter().filter(|p| {
            [Stat::FoldSmallBlindToSteal, Stat::FoldBigBlindToSteal].iter()
                .any(|s| s.evaluate(&a, p).is_some())
        }).count();
        prop_assert!(defenders <= 2);
    }

    /// Independent, deliberately naive recomputation of the core stats from raw actions.
    #[test]
    fn core_stats_match_a_naive_oracle(bytes in entropy_strategy()) {
        let hand = random_hand(&bytes);
        let a = analyze(&hand).unwrap();
        for p in &a.players {
            let preflop: Vec<_> = hand.actions.iter()
                .filter(|e| e.street == Street::Preflop && e.seat == p.seat)
                .collect();
            let voluntary = preflop.iter().any(|e| matches!(e.kind,
                ActionKind::Call{..} | ActionKind::Bet{..} | ActionKind::RaiseTo{..}));
            let raised = preflop.iter().any(|e| matches!(e.kind, ActionKind::RaiseTo{..}));
            prop_assert_eq!(Stat::Vpip.evaluate(&a, p), Some(voluntary));
            prop_assert_eq!(Stat::Pfr.evaluate(&a, p), Some(raised));
            let folded_pre = hand.actions.iter().any(|e| e.seat == p.seat
                && e.street == Street::Preflop && matches!(e.kind, ActionKind::Fold));
            let flop_dealt = hand.board.iter().any(|b| b.street == Street::Flop);
            prop_assert_eq!(p.saw_flop, flop_dealt && !folded_pre);
            let contributed: i64 = hand.actions.iter().filter(|e| e.seat == p.seat)
                .map(|e| match &e.kind {
                    ActionKind::PostSmallBlind{amount_added} | ActionKind::PostBigBlind{amount_added}
                    | ActionKind::PostAnte{amount_added} | ActionKind::Call{amount_added}
                    | ActionKind::Bet{amount_added} => amount_added.0,
                    ActionKind::ReturnUncalled{amount} => -amount.0,
                    _ => 0,
                }).sum::<i64>() + street_raise_deltas(&hand, p.seat);
            prop_assert_eq!(p.invested, contributed);
            let won: i64 = hand.awards.iter().filter(|w| w.seat == p.seat).map(|w| w.amount.0).sum();
            prop_assert_eq!(p.collected, won);
            // Naive 3-bet opportunity: faced exactly one earlier preflop raise, had chips beyond the call.
            let mut raises = 0;
            let mut opportunity = None;
            for e in hand.actions.iter().filter(|e| e.street == Street::Preflop) {
                if e.seat == p.seat && raises == 1 && opportunity.is_none() {
                    let outstanding = outstanding_before(&hand, e.sequence as usize);
                    let stack = p.starting_stack - contributed_before(&hand, e.sequence as usize, p.seat);
                    if !matches!(e.kind, ActionKind::PostSmallBlind{..}|ActionKind::PostBigBlind{..}|ActionKind::PostAnte{..}|ActionKind::ReturnUncalled{..})
                        && stack > outstanding {
                        opportunity = Some(matches!(e.kind, ActionKind::RaiseTo{..}));
                    }
                }
                if matches!(e.kind, ActionKind::RaiseTo{..}) { raises += 1; }
            }
            // "Faced exactly one raise" is the first decision made at raise count 1;
            // later decisions after more raises are excluded by `opportunity.is_none()`
            // only when this player already decided at count 1.
            prop_assert_eq!(Stat::ThreeBet.evaluate(&a, p), opportunity);
        }
    }

    #[test]
    fn analysis_is_deterministic_and_survives_a_json_round_trip(bytes in entropy_strategy()) {
        let hand = random_hand(&bytes);
        let json = serde_json::to_string(&hand).unwrap();
        let back: openriver_domain::Hand = serde_json::from_str(&json).unwrap();
        prop_assert_eq!(&back, &hand);
        prop_assert_eq!(analyze(&hand).unwrap(), analyze(&back).unwrap());
    }

    /// A hand stored before `button_seat` existed has no position data but still yields stats.
    #[test]
    fn hands_without_a_button_degrade_to_unknown_positions(bytes in entropy_strategy()) {
        let mut hand = random_hand(&bytes);
        let mut value: serde_json::Value = serde_json::to_value(&hand).unwrap();
        value.as_object_mut().unwrap().remove("button_seat");
        hand = serde_json::from_value(value).unwrap();
        prop_assert_eq!(hand.button_seat, None);
        let a = analyze(&hand).unwrap();
        for p in &a.players {
            // Core stats never need the button.
            prop_assert!(Stat::Vpip.evaluate(&a, p).is_some());
            if let Some(Position::Button) = p.position { prop_assert!(false, "no button without a button seat"); }
        }
    }

    #[test]
    fn merging_and_ordering_never_change_totals(
        seeds in proptest::collection::vec(proptest::collection::vec(any::<u8>(), 64..300), 1..40),
        split in any::<prop::sample::Index>(),
    ) {
        let hands: Vec<_> = seeds.iter().enumerate().map(|(i, b)| {
            let mut hand = random_hand(b);
            hand.provenance.external_hand_id = i.to_string();
            hand
        }).collect();
        let mut whole = StatsEngine::default();
        for h in &hands { whole.add_hand(h).unwrap(); }
        // Reversed order.
        let mut reversed = StatsEngine::default();
        for h in hands.iter().rev() { reversed.add_hand(h).unwrap(); }
        // Two halves merged.
        let cut = split.index(hands.len() + 1);
        let (mut left, mut right) = (StatsEngine::default(), StatsEngine::default());
        for h in &hands[..cut] { left.add_hand(h).unwrap(); }
        for h in &hands[cut..] { right.add_hand(h).unwrap(); }
        left.merge(&right);
        for other in [&reversed, &left] {
            prop_assert_eq!(other.hands_counted(), whole.hands_counted());
            prop_assert_eq!(other.players().count(), whole.players().count());
            for (key, stats) in whole.players() {
                prop_assert!(same(stats, other.player(&key.room, &key.name).unwrap()));
            }
        }
    }

    #[test]
    fn filters_only_ever_remove_data(bytes in proptest::collection::vec(any::<u8>(), 64..400)) {
        let hand = random_hand(&bytes);
        let mut all = StatsEngine::default();
        all.add_hand(&hand).unwrap();
        for filter in [
            HandFilter { min_players: Some(100), ..Default::default() },
            HandFilter { max_big_blind: Some(0), ..Default::default() },
            HandFilter { currency: Some("EUR".into()), ..Default::default() },
            HandFilter { from: Some("2999-01-01T00:00:00Z".into()), ..Default::default() },
            HandFilter { rooms: Some(BTreeSet::from(["other".to_string()])), ..Default::default() },
        ] {
            let mut e = StatsEngine::new(filter);
            e.add_hand(&hand).unwrap();
            prop_assert_eq!((e.hands_seen(), e.hands_counted()), (1, 0));
            prop_assert_eq!(e.players().count(), 0);
        }
        let late = HandFilter {
            position_groups: Some(BTreeSet::from([PositionGroup::Late])),
            ..Default::default()
        };
        let mut e = StatsEngine::new(late);
        e.add_hand(&hand).unwrap();
        for (key, stats) in e.players() {
            // Late-position players are a subset, with identical per-hand results.
            let full = all.player(&key.room, &key.name).unwrap();
            prop_assert_eq!(stats.hands, 1);
            prop_assert_eq!(stats.get(Stat::Vpip), full.get(Stat::Vpip));
        }
        prop_assert!(e.players().count() <= all.players().count());
    }

    #[test]
    fn rates_and_intervals_are_always_sane(
        seeds in proptest::collection::vec(proptest::collection::vec(any::<u8>(), 64..300), 1..30),
    ) {
        let mut engine = StatsEngine::default();
        for (i, b) in seeds.iter().enumerate() {
            let mut hand = random_hand(b);
            hand.provenance.external_hand_id = i.to_string();
            engine.add_hand(&hand).unwrap();
        }
        for (_, stats) in engine.players() {
            prop_assert!(stats.get(Stat::Pfr).successes() <= stats.get(Stat::Vpip).successes());
            prop_assert_eq!(stats.get(Stat::Vpip).sample_size(), stats.hands);
            for stat in Stat::ALL {
                let c = stats.get(stat);
                prop_assert!(c.successes() <= c.sample_size() && c.sample_size() <= stats.hands);
                if let (Some(rate), Some((lo, hi))) = (c.rate(), c.wilson_interval_95()) {
                    prop_assert!(0.0 <= lo && lo <= rate + 1e-12 && rate <= hi + 1e-12 && hi <= 1.0);
                } else {
                    prop_assert!(c.rate().is_none() && c.wilson_interval_95().is_none());
                }
            }
            if let Some(f) = stats.postflop.factor() { prop_assert!(f >= 0.0); }
            if let Some(f) = stats.postflop.frequency() { prop_assert!((0.0..=1.0).contains(&f)); }
        }
    }
}

fn same(a: &PlayerStats, b: &PlayerStats) -> bool {
    a.hands == b.hands
        && a.postflop == b.postflop
        && a.money.net == b.money.net
        && a.money.net_at_showdown == b.money.net_at_showdown
        && a.money.net_without_showdown == b.money.net_without_showdown
        && (a.money.net_big_blinds - b.money.net_big_blinds).abs() < 1e-6
        && Stat::ALL.iter().all(|s| a.get(*s) == b.get(*s))
}

/// Raise deltas need the player's running street contribution, so recompute them.
fn street_raise_deltas(hand: &openriver_domain::Hand, seat: u8) -> i64 {
    let mut street = Street::Preflop;
    let mut on_street = 0i64;
    let mut total = 0i64;
    for e in hand.actions.iter().filter(|e| e.seat == seat) {
        if e.street != street {
            street = e.street;
            on_street = 0;
        }
        match &e.kind {
            ActionKind::PostSmallBlind { amount_added }
            | ActionKind::PostBigBlind { amount_added }
            | ActionKind::Call { amount_added }
            | ActionKind::Bet { amount_added } => on_street += amount_added.0,
            ActionKind::ReturnUncalled { amount } => on_street -= amount.0,
            ActionKind::RaiseTo {
                total_street_contribution,
            } => {
                total += total_street_contribution.0 - on_street;
                on_street = total_street_contribution.0;
            }
            _ => {}
        }
    }
    total
}

fn street_totals_before(
    hand: &openriver_domain::Hand,
    upto: usize,
) -> std::collections::BTreeMap<u8, i64> {
    let mut totals = std::collections::BTreeMap::new();
    for e in &hand.actions[..upto] {
        if e.street != Street::Preflop {
            break;
        }
        let entry = totals.entry(e.seat).or_insert(0i64);
        match &e.kind {
            ActionKind::PostSmallBlind { amount_added }
            | ActionKind::PostBigBlind { amount_added }
            | ActionKind::Call { amount_added }
            | ActionKind::Bet { amount_added } => *entry += amount_added.0,
            ActionKind::RaiseTo {
                total_street_contribution,
            } => *entry = total_street_contribution.0,
            ActionKind::ReturnUncalled { amount } => *entry -= amount.0,
            _ => {}
        }
    }
    totals
}

fn outstanding_before(hand: &openriver_domain::Hand, index: usize) -> i64 {
    let totals = street_totals_before(hand, index);
    let me = hand.actions[index].seat;
    totals.values().copied().max().unwrap_or(0) - totals.get(&me).copied().unwrap_or(0)
}

fn contributed_before(hand: &openriver_domain::Hand, index: usize, seat: u8) -> i64 {
    let mut total = 0i64;
    let mut street = Street::Preflop;
    let mut on_street = 0i64;
    for e in hand.actions[..index].iter().filter(|e| e.seat == seat) {
        if e.street != street {
            street = e.street;
            on_street = 0;
        }
        match &e.kind {
            ActionKind::PostAnte { amount_added } => total += amount_added.0,
            ActionKind::PostSmallBlind { amount_added }
            | ActionKind::PostBigBlind { amount_added }
            | ActionKind::Call { amount_added }
            | ActionKind::Bet { amount_added } => {
                on_street += amount_added.0;
                total += amount_added.0;
            }
            ActionKind::RaiseTo {
                total_street_contribution,
            } => {
                total += total_street_contribution.0 - on_street;
                on_street = total_street_contribution.0;
            }
            ActionKind::ReturnUncalled { amount } => {
                on_street -= amount.0;
                total -= amount.0;
            }
            _ => {}
        }
    }
    total
}
