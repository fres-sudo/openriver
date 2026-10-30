//! Step-by-step table states for replaying one validated hand.
//!
//! The replay restates the canonical hand as a sequence of table snapshots:
//! step 0 is the table before any chip moves, and each later step applies one
//! event. Every snapshot is complete, so a viewer can jump to any step without
//! re-deriving poker rules, and a step index is a stable address for notes.

use crate::analysis::{analyze, AnalysisError};
use crate::position::Position;
use openriver_domain::{ActionEvent, ActionKind, Card, Chips, Hand, Pot, Street};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Replay {
    pub currency: String,
    pub currency_scale: u8,
    pub small_blind: Chips,
    pub big_blind: Chips,
    pub ante: Chips,
    pub table_capacity: u8,
    /// `None` when the source did not say where the button was.
    pub button_seat: Option<u8>,
    pub steps: Vec<ReplayStep>,
}

/// What changed between the previous step and this one.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ReplayEvent {
    /// Players seated with their starting stacks; nothing posted yet.
    Start,
    /// One canonical action, including forced posts and uncalled returns.
    Action(ActionEvent),
    /// Bets were collected into the pot and this street's cards were dealt.
    /// `cards` is empty only if the source recorded actions on a street
    /// without its board cards.
    Street { street: Street, cards: Vec<Card> },
    /// Bets were collected and the remaining players reached showdown.
    Showdown,
    /// Chips moved from the pot to a player. Bets still in front of players
    /// are collected first when no showdown step did so.
    Award {
        pot_index: usize,
        seat: u8,
        amount: Chips,
    },
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SeatStatus {
    /// Still in the hand with chips behind.
    Active,
    Folded,
    AllIn,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SeatView {
    pub seat: u8,
    pub name: String,
    pub position: Option<Position>,
    pub stack: Chips,
    /// Chips in front of the player on the current street, not yet collected.
    pub bet: Chips,
    pub status: SeatStatus,
    /// The player's latest action on the current street, cleared when bets
    /// are collected. Uncalled returns do not replace it.
    pub last_action: Option<ActionKind>,
    /// Exactly what the source reported; unknown cards stay unknown. Whether
    /// to hide known cards before showdown is a presentation choice.
    pub hole_cards: Option<[Option<Card>; 2]>,
    /// Total awarded to this player so far.
    pub won: Chips,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ReplayStep {
    pub event: ReplayEvent,
    pub street: Street,
    /// Board cards dealt so far.
    pub board: Vec<Card>,
    /// Ordered by seat number.
    pub seats: Vec<SeatView>,
    /// Chips collected in the middle, excluding bets still in front of players.
    /// After the last award this is exactly the rake.
    pub pot: Chips,
    /// The hand's declared pots, present from the showdown or first award on.
    pub pots: Vec<Pot>,
    /// Seat that makes the next decision, when the next step is a decision.
    pub next_to_act: Option<u8>,
}

impl ReplayStep {
    /// Everything in the middle, including uncollected bets.
    pub fn total_pot(&self) -> Chips {
        Chips(self.pot.0 + self.seats.iter().map(|seat| seat.bet.0).sum::<i64>())
    }
}

fn is_decision(kind: &ActionKind) -> bool {
    matches!(
        kind,
        ActionKind::Fold
            | ActionKind::Check
            | ActionKind::Call { .. }
            | ActionKind::Bet { .. }
            | ActionKind::RaiseTo { .. }
    )
}

struct State {
    street: Street,
    board: Vec<Card>,
    seats: Vec<SeatView>,
    pot: i64,
    pots: Vec<Pot>,
}

impl State {
    fn seat_mut(&mut self, seat: u8) -> &mut SeatView {
        self.seats
            .iter_mut()
            .find(|view| view.seat == seat)
            .expect("validated hands only reference seated players")
    }

    fn collect(&mut self) {
        for seat in &mut self.seats {
            self.pot += seat.bet.0;
            seat.bet = Chips(0);
            seat.last_action = None;
        }
    }

    fn apply(&mut self, event: &ActionEvent) {
        let view = self.seat_mut(event.seat);
        let delta = match event.kind {
            ActionKind::Fold | ActionKind::Check => 0,
            ActionKind::Call { amount_added }
            | ActionKind::Bet { amount_added }
            | ActionKind::PostSmallBlind { amount_added }
            | ActionKind::PostBigBlind { amount_added } => amount_added.0,
            ActionKind::RaiseTo {
                total_street_contribution,
            } => total_street_contribution.0 - view.bet.0,
            ActionKind::ReturnUncalled { amount } => -amount.0,
            // Antes go straight to the middle; they are not a street bet.
            ActionKind::PostAnte { amount_added } => {
                view.stack.0 -= amount_added.0;
                if event.all_in {
                    view.status = SeatStatus::AllIn;
                }
                self.pot += amount_added.0;
                return;
            }
        };
        view.stack.0 -= delta;
        view.bet.0 += delta;
        match event.kind {
            ActionKind::Fold => view.status = SeatStatus::Folded,
            ActionKind::ReturnUncalled { .. } => {
                // A returned bet gives an all-in player chips back.
                if view.status == SeatStatus::AllIn && view.stack.0 > 0 {
                    view.status = SeatStatus::Active;
                }
                return;
            }
            _ if event.all_in => view.status = SeatStatus::AllIn,
            _ => {}
        }
        view.last_action = Some(event.kind.clone());
    }

    fn snapshot(&self, event: ReplayEvent) -> ReplayStep {
        ReplayStep {
            event,
            street: self.street,
            board: self.board.clone(),
            seats: self.seats.clone(),
            pot: Chips(self.pot),
            pots: self.pots.clone(),
            next_to_act: None,
        }
    }
}

/// Build every table state of a hand, after checking it with the same
/// validator the statistics use.
pub fn replay(hand: &Hand) -> Result<Replay, AnalysisError> {
    let analysis = analyze(hand)?;
    let mut seats: Vec<SeatView> = hand
        .players
        .iter()
        .map(|player| SeatView {
            seat: player.seat,
            name: player.name.clone(),
            position: analysis.player(player.seat).and_then(|p| p.position),
            stack: player.starting_stack,
            bet: Chips(0),
            status: SeatStatus::Active,
            last_action: None,
            hole_cards: player.hole_cards,
            won: Chips(0),
        })
        .collect();
    seats.sort_unstable_by_key(|view| view.seat);
    let mut state = State {
        street: Street::Preflop,
        board: Vec::new(),
        seats,
        pot: 0,
        pots: Vec::new(),
    };
    let mut steps = vec![state.snapshot(ReplayEvent::Start)];
    let mut board = hand.board.iter().peekable();
    let mut deal_until = |state: &mut State, steps: &mut Vec<ReplayStep>, street: Street| {
        while state.street != street && state.street != Street::River {
            state.collect();
            let next = match state.street {
                Street::Preflop => Street::Flop,
                Street::Flop => Street::Turn,
                _ => Street::River,
            };
            let cards = board
                .next_if(|event| event.street == next)
                .map(|event| event.cards.clone())
                .unwrap_or_default();
            state.board.extend(cards.iter().copied());
            state.street = next;
            steps.push(state.snapshot(ReplayEvent::Street {
                street: next,
                cards,
            }));
        }
    };
    for event in &hand.actions {
        deal_until(&mut state, &mut steps, event.street);
        state.apply(event);
        steps.push(state.snapshot(ReplayEvent::Action(event.clone())));
    }
    // An all-in run-out deals the remaining board with no further actions.
    if let Some(last) = hand.board.last() {
        deal_until(&mut state, &mut steps, last.street);
    }
    state.pots = hand.pots.clone();
    if analysis.went_to_showdown {
        state.collect();
        state.street = Street::Showdown;
        steps.push(state.snapshot(ReplayEvent::Showdown));
    }
    for award in &hand.awards {
        state.collect();
        state.pot -= award.amount.0;
        let view = state.seat_mut(award.seat);
        view.stack.0 += award.amount.0;
        view.won.0 += award.amount.0;
        steps.push(state.snapshot(ReplayEvent::Award {
            pot_index: award.pot_index,
            seat: award.seat,
            amount: award.amount,
        }));
    }
    for index in 1..steps.len() {
        if let ReplayEvent::Action(event) = &steps[index].event {
            if is_decision(&event.kind) {
                steps[index - 1].next_to_act = Some(event.seat);
            }
        }
    }
    Ok(Replay {
        currency: hand.game.currency.clone(),
        currency_scale: hand.game.currency_scale,
        small_blind: hand.game.small_blind,
        big_blind: hand.game.big_blind,
        ante: hand.game.ante,
        table_capacity: hand.game.table_capacity,
        button_seat: hand.button_seat,
        steps,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::analysis::analyze;
    use crate::properties::random_hand;
    use crate::testkit::Table;
    use proptest::prelude::*;

    fn seat(step: &ReplayStep, seat: u8) -> &SeatView {
        step.seats.iter().find(|view| view.seat == seat).unwrap()
    }

    fn chips_on_table(step: &ReplayStep) -> i64 {
        step.total_pot().0 + step.seats.iter().map(|view| view.stack.0).sum::<i64>()
    }

    /// Facts every replay must satisfy, whatever the hand.
    fn check_invariants(hand: &Hand) {
        let replay = replay(hand).unwrap();
        let analysis = analyze(hand).unwrap();
        let steps = &replay.steps;
        let starting: i64 = hand.players.iter().map(|p| p.starting_stack.0).sum();
        assert_eq!(steps[0].event, ReplayEvent::Start);
        assert_eq!(steps[0].total_pot(), Chips(0));
        let mut last_street = Street::Preflop;
        for step in steps {
            // Chips are only ever moved, never created or lost.
            assert_eq!(chips_on_table(step), starting, "{:?}", step.event);
            assert!(step.pot.0 >= 0);
            assert!(step.seats.iter().all(|v| v.stack.0 >= 0 && v.bet.0 >= 0));
            assert!(step.street as u8 >= last_street as u8);
            last_street = step.street;
            // An all-in player holds nothing beyond what they have been awarded.
            assert!(step
                .seats
                .iter()
                .all(|v| (v.status == SeatStatus::AllIn) <= (v.stack == v.won)));
        }
        let actions: Vec<_> = steps
            .iter()
            .filter_map(|step| match &step.event {
                ReplayEvent::Action(event) => Some(event.clone()),
                _ => None,
            })
            .collect();
        assert_eq!(actions, hand.actions);
        let last = steps.last().unwrap();
        // After the awards only the rake is left in the middle.
        assert_eq!(last.total_pot(), hand.rake);
        assert_eq!(last.pots, hand.pots);
        let dealt: Vec<Card> = hand.board.iter().flat_map(|b| b.cards.clone()).collect();
        assert_eq!(last.board, dealt);
        for player in &analysis.players {
            let view = seat(last, player.seat);
            assert_eq!(view.stack.0, player.starting_stack + player.net);
            assert_eq!(view.won.0, player.collected);
            assert_eq!(view.position, player.position);
        }
        assert_eq!(
            steps.iter().any(|s| s.event == ReplayEvent::Showdown),
            analysis.went_to_showdown
        );
        for pair in steps.windows(2) {
            let expected = match &pair[1].event {
                ReplayEvent::Action(event) if is_decision(&event.kind) => Some(event.seat),
                _ => None,
            };
            assert_eq!(pair[0].next_to_act, expected);
        }
    }

    #[test]
    fn golden_side_pot_replays_step_by_step() {
        let parsed = openriver_parser::parse(include_bytes!(
            "../../../fixtures/hands/golden_side_pot.txt"
        ))
        .unwrap();
        let hand = &parsed.hands[0];
        check_invariants(hand);
        let steps = replay(hand).unwrap().steps;
        let kinds: Vec<String> = steps
            .iter()
            .map(|step| match &step.event {
                ReplayEvent::Start => "start".into(),
                ReplayEvent::Action(e) => format!("{}:{:?}", e.seat, e.kind),
                ReplayEvent::Street { street, cards } => format!("{street:?}/{}", cards.len()),
                ReplayEvent::Showdown => "showdown".into(),
                ReplayEvent::Award {
                    pot_index,
                    seat,
                    amount,
                } => format!("award {pot_index}->{seat} {}", amount.0),
            })
            .collect();
        assert_eq!(
            kinds,
            [
                "start",
                "1:PostSmallBlind { amount_added: Chips(1) }",
                "2:PostBigBlind { amount_added: Chips(2) }",
                "3:RaiseTo { total_street_contribution: Chips(300) }",
                "1:Call { amount_added: Chips(99) }",
                "2:Call { amount_added: Chips(198) }",
                "3:ReturnUncalled { amount: Chips(100) }",
                "Flop/3",
                "Turn/1",
                "River/1",
                "showdown",
                "award 0->1 300",
                "award 1->2 200",
            ]
        );
        // After the return Cy has 100 behind, matched by nobody, so not all-in.
        let returned = &steps[6];
        assert_eq!(seat(returned, 3).stack, Chips(100));
        assert_eq!(seat(returned, 3).bet, Chips(200));
        assert_eq!(seat(returned, 3).status, SeatStatus::Active);
        // The return keeps the raise as Cy's displayed action.
        assert!(matches!(
            seat(returned, 3).last_action,
            Some(ActionKind::RaiseTo { .. })
        ));
        assert_eq!(seat(returned, 1).status, SeatStatus::AllIn);
        assert_eq!(returned.total_pot(), Chips(500));
        // Dealing the flop collects the bets and clears the action labels.
        let flop = &steps[7];
        assert_eq!(flop.pot, Chips(500));
        assert!(flop
            .seats
            .iter()
            .all(|v| v.bet.0 == 0 && v.last_action.is_none()));
        assert_eq!(flop.board.len(), 3);
        // The raise is the only decision Cy faces; then the blinds respond.
        assert_eq!(steps[2].next_to_act, Some(3));
        assert_eq!(steps[3].next_to_act, Some(1));
        assert_eq!(steps[5].next_to_act, None);
        assert_eq!(steps[10].street, Street::Showdown);
        assert!(steps[10].pots.len() == 2 && steps[9].pots.is_empty());
    }

    #[test]
    fn walk_awards_without_showdown_and_collects_blinds() {
        let mut t = Table::new(&[(1, 200), (2, 200), (3, 200)], 1, 6, 1, 2);
        t.fold(1).fold(2);
        let hand = t.finish_first_wins();
        check_invariants(&hand);
        let steps = replay(&hand).unwrap().steps;
        assert!(!steps.iter().any(|s| s.event == ReplayEvent::Showdown));
        let last = steps.last().unwrap();
        assert!(matches!(last.event, ReplayEvent::Award { seat: 3, .. }));
        assert!(last.seats.iter().all(|v| v.bet.0 == 0));
        assert_eq!(seat(last, 3).stack, Chips(201));
        assert_eq!(seat(last, 2).status, SeatStatus::Folded);
    }

    #[test]
    fn antes_go_to_the_middle_not_in_front() {
        let mut t = Table::with_ante(&[(1, 100), (2, 100), (3, 100)], 1, 6, 1, 2, 1);
        t.fold(1).fold(2);
        let hand = t.finish_first_wins();
        check_invariants(&hand);
        let steps = replay(&hand).unwrap().steps;
        let after_antes = steps
            .iter()
            .rposition(|s| {
                matches!(&s.event, ReplayEvent::Action(e)
                    if matches!(e.kind, ActionKind::PostAnte { .. }))
            })
            .unwrap();
        let step = &steps[after_antes];
        assert_eq!(step.pot, Chips(3));
        assert!(step
            .seats
            .iter()
            .all(|v| v.bet.0 == 0 && v.last_action.is_none()));
    }

    #[test]
    fn all_parser_fixtures_replay() {
        let dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/hands");
        let mut replayed = 0;
        for entry in std::fs::read_dir(dir).unwrap() {
            let path = entry.unwrap().path();
            if path.extension().is_none_or(|ext| ext != "txt") {
                continue;
            }
            let Ok(parsed) = openriver_parser::parse(&std::fs::read(&path).unwrap()) else {
                continue; // intentionally unsupported inputs
            };
            for hand in &parsed.hands {
                check_invariants(hand);
                replayed += 1;
            }
        }
        assert!(
            replayed >= 9,
            "expected the accepted fixtures, saw {replayed}"
        );
    }

    proptest! {
        #![proptest_config(ProptestConfig::with_cases(1000))]

        #[test]
        fn random_hands_replay_consistently(
            bytes in proptest::collection::vec(any::<u8>(), 64..600)
        ) {
            check_invariants(&random_hand(&bytes));
        }
    }
}
