//! Replays one validated hand into the facts statistics are defined on.
//!
//! The analysis never guesses: it only restates what the canonical hand
//! already says, so every statistic derived from it is traceable to actions.

use crate::position::{assign_positions, Position};
use openriver_domain::{validate_hand, ActionKind, Card, Hand, HandError, Street};
use std::collections::{BTreeMap, BTreeSet};

#[derive(Clone, Debug, thiserror::Error, PartialEq, Eq)]
pub enum AnalysisError {
    #[error("the hand failed canonical validation")]
    InvalidHand(#[from] HandError),
}

/// What a player chose to do. Forced posts and uncalled-bet returns are not decisions.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Act {
    Fold,
    Check,
    Call,
    Bet,
    Raise,
}

impl Act {
    pub fn is_aggressive(self) -> bool {
        matches!(self, Self::Bet | Self::Raise)
    }
}

/// One player decision together with the situation it was made in.
///
/// "Bet level" counts aggressive actions on the street, with the big blind
/// counting as the first preflop: level 1 preflop is an unraised pot, level 2
/// is facing an open raise, level 3 facing a 3-bet, and so on. Postflop level
/// 0 is unbet and level 1 is facing a bet.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Decision {
    /// Index into `Hand::actions`.
    pub action_index: usize,
    pub street: Street,
    pub seat: u8,
    pub act: Act,
    pub all_in: bool,
    pub bet_level_before: u8,
    /// Chips needed to call, before this action.
    pub to_call: i64,
    /// Chips the player still holds behind, before this action.
    pub stack_behind: i64,
    pub pot_before: i64,
    /// Opponents who have not folded.
    pub live_opponents: u8,
    /// Opponents who have not folded and are not all-in.
    pub opponents_with_chips: u8,
    /// Preflop callers at level 1 (limpers) before this action.
    pub limpers_before: u8,
    /// No player has called, bet or raised yet on this street.
    pub first_in: bool,
    /// Seat of the last bettor/raiser on this street, if any.
    pub aggressor: Option<u8>,
    /// The player has not acted before this decision in the hand.
    pub first_decision_of_hand: bool,
}

impl Decision {
    /// Whether the player could have raised: chips remain beyond the call.
    pub fn could_raise(&self) -> bool {
        self.stack_behind > self.to_call
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PlayerSummary {
    pub seat: u8,
    pub name: String,
    pub position: Option<Position>,
    pub starting_stack: i64,
    pub hole_cards: Option<[Option<Card>; 2]>,
    /// Chips put in, net of any uncalled return.
    pub invested: i64,
    pub collected: i64,
    /// `collected - invested`. Rake is not attributed to individual players.
    pub net: i64,
    pub saw_flop: bool,
    pub saw_turn: bool,
    pub saw_river: bool,
    pub went_to_showdown: bool,
    pub folded_on: Option<Street>,
    /// The player posted the small or big blind (an ante alone does not count).
    pub posted_blind: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct HandAnalysis {
    pub players: Vec<PlayerSummary>,
    pub decisions: Vec<Decision>,
    pub big_blind: i64,
    pub currency: String,
    pub currency_scale: u8,
    pub played_at: String,
    pub went_to_showdown: bool,
    /// The last player to raise preflop, if anyone raised.
    pub preflop_aggressor: Option<u8>,
}

impl HandAnalysis {
    pub fn player(&self, seat: u8) -> Option<&PlayerSummary> {
        self.players.iter().find(|player| player.seat == seat)
    }

    pub fn decisions_of(&self, seat: u8) -> impl Iterator<Item = &Decision> {
        self.decisions
            .iter()
            .filter(move |decision| decision.seat == seat)
    }

    pub fn street_decisions(&self, street: Street) -> impl Iterator<Item = &Decision> {
        self.decisions
            .iter()
            .filter(move |decision| decision.street == street)
    }
}

pub fn analyze(hand: &Hand) -> Result<HandAnalysis, AnalysisError> {
    validate_hand(hand)?;
    let stacks: BTreeMap<u8, i64> = hand
        .players
        .iter()
        .map(|player| (player.seat, player.starting_stack.0))
        .collect();
    let mut totals: BTreeMap<u8, i64> = stacks.keys().map(|seat| (*seat, 0)).collect();
    let mut street_totals = totals.clone();
    let mut folded_on: BTreeMap<u8, Street> = BTreeMap::new();
    let mut all_in: BTreeSet<u8> = BTreeSet::new();
    let mut acted: BTreeSet<u8> = BTreeSet::new();
    let mut decisions = Vec::new();
    let mut pot = 0i64;
    let mut level = 0u8;
    let mut aggressor: Option<u8> = None;
    let mut voluntary = false;
    let mut limpers = 0u8;
    let mut small_blind_seat = None;
    let mut big_blind_seat = None;
    let mut preflop_aggressor = None;
    let mut current_street = Street::Preflop;

    for (index, event) in hand.actions.iter().enumerate() {
        if street_rank(event.street) != street_rank(current_street) {
            current_street = event.street;
            street_totals.values_mut().for_each(|amount| *amount = 0);
            level = 0;
            aggressor = None;
            voluntary = false;
            limpers = 0;
        }
        let seat = event.seat;
        let current = street_totals[&seat];
        let highest = street_totals.values().copied().max().unwrap_or(0);
        let delta = match &event.kind {
            ActionKind::Fold | ActionKind::Check => 0,
            ActionKind::Call { amount_added }
            | ActionKind::Bet { amount_added }
            | ActionKind::PostSmallBlind { amount_added }
            | ActionKind::PostBigBlind { amount_added }
            | ActionKind::PostAnte { amount_added } => amount_added.0,
            ActionKind::RaiseTo {
                total_street_contribution,
            } => total_street_contribution.0 - current,
            ActionKind::ReturnUncalled { amount } => -amount.0,
        };
        let act = match &event.kind {
            ActionKind::Fold => Some(Act::Fold),
            ActionKind::Check => Some(Act::Check),
            ActionKind::Call { .. } => Some(Act::Call),
            ActionKind::Bet { .. } => Some(Act::Bet),
            ActionKind::RaiseTo { .. } => Some(Act::Raise),
            _ => None,
        };
        if let Some(act) = act {
            let live = |predicate: &dyn Fn(u8) -> bool| {
                stacks
                    .keys()
                    .filter(|other| **other != seat && !folded_on.contains_key(other))
                    .filter(|other| predicate(**other))
                    .count() as u8
            };
            decisions.push(Decision {
                action_index: index,
                street: event.street,
                seat,
                act,
                all_in: event.all_in,
                bet_level_before: level,
                to_call: highest - current,
                stack_behind: stacks[&seat] - totals[&seat],
                pot_before: pot,
                live_opponents: live(&|_| true),
                opponents_with_chips: live(&|other| !all_in.contains(&other)),
                limpers_before: limpers,
                first_in: !voluntary,
                aggressor,
                first_decision_of_hand: !acted.contains(&seat),
            });
            acted.insert(seat);
            match act {
                Act::Fold => {
                    folded_on.insert(seat, event.street);
                }
                Act::Call => {
                    voluntary = true;
                    if event.street == Street::Preflop && level == 1 {
                        limpers += 1;
                    }
                }
                Act::Bet | Act::Raise => {
                    voluntary = true;
                    level = level.saturating_add(1);
                    aggressor = Some(seat);
                    if event.street == Street::Preflop {
                        preflop_aggressor = Some(seat);
                    }
                }
                Act::Check => {}
            }
        } else {
            match event.kind {
                ActionKind::PostSmallBlind { .. } => small_blind_seat = Some(seat),
                ActionKind::PostBigBlind { .. } => {
                    big_blind_seat = Some(seat);
                    level = 1;
                }
                _ => {}
            }
        }
        if !matches!(event.kind, ActionKind::PostAnte { .. }) {
            street_totals.insert(seat, current + delta);
        }
        *totals.get_mut(&seat).expect("validated seat") += delta;
        pot += delta;
        if event.all_in {
            all_in.insert(seat);
        }
    }

    let mut collected: BTreeMap<u8, i64> = BTreeMap::new();
    for award in &hand.awards {
        *collected.entry(award.seat).or_insert(0) += award.amount.0;
    }
    let remaining: BTreeSet<u8> = stacks
        .keys()
        .copied()
        .filter(|seat| !folded_on.contains_key(seat))
        .collect();
    let went_to_showdown = remaining.len() >= 2;
    let board_has = |street: Street| hand.board.iter().any(|event| event.street == street);
    let reached = |seat: u8, street: Street| {
        board_has(street)
            && folded_on
                .get(&seat)
                .is_none_or(|fold| street_rank(*fold) >= street_rank(street))
    };
    let occupied: Vec<u8> = stacks.keys().copied().collect();
    let positions = match (small_blind_seat, big_blind_seat) {
        (Some(sb), Some(bb)) => assign_positions(&occupied, hand.button_seat, sb, bb),
        _ => None,
    };
    let players = hand
        .players
        .iter()
        .map(|player| {
            let seat = player.seat;
            let invested = totals[&seat];
            let collected = collected.get(&seat).copied().unwrap_or(0);
            PlayerSummary {
                seat,
                name: player.name.clone(),
                position: positions.as_ref().and_then(|map| map.get(&seat).copied()),
                starting_stack: player.starting_stack.0,
                hole_cards: player.hole_cards,
                invested,
                collected,
                net: collected - invested,
                saw_flop: reached(seat, Street::Flop),
                saw_turn: reached(seat, Street::Turn),
                saw_river: reached(seat, Street::River),
                went_to_showdown: went_to_showdown && remaining.contains(&seat),
                folded_on: folded_on.get(&seat).copied(),
                posted_blind: small_blind_seat == Some(seat) || big_blind_seat == Some(seat),
            }
        })
        .collect();
    Ok(HandAnalysis {
        players,
        decisions,
        big_blind: hand.game.big_blind.0,
        currency: hand.game.currency.clone(),
        currency_scale: hand.game.currency_scale,
        played_at: hand.played_at.clone(),
        went_to_showdown,
        preflop_aggressor,
    })
}

fn street_rank(street: Street) -> u8 {
    match street {
        Street::Preflop => 0,
        Street::Flop => 1,
        Street::Turn => 2,
        Street::River => 3,
        Street::Showdown => 4,
    }
}
