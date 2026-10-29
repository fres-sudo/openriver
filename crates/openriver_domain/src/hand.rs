//! Lossless canonical hand facts and accounting checks shared by room adapters.

use crate::{validate_unique_cards, ActionKind, Card, Chips, Street};
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};
use thiserror::Error;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum GameVariant {
    NoLimitHoldem,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GameDefinition {
    pub variant: GameVariant,
    pub currency: String,
    /// Decimal digits in one major currency unit; USD cents use 2.
    pub currency_scale: u8,
    pub small_blind: Chips,
    pub big_blind: Chips,
    pub ante: Chips,
    pub table_capacity: u8,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Provenance {
    pub room: String,
    pub external_hand_id: String,
    pub parser_version: String,
    pub source_sha256: String,
    pub start_line: usize,
    pub end_line: usize,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct PlayerAtSeat {
    pub seat: u8,
    pub name: String,
    pub starting_stack: Chips,
    /// None means unreported. Unknown or mucked cards stay unknown.
    pub hole_cards: Option<[Option<Card>; 2]>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ActionEvent {
    pub sequence: u32,
    pub street: Street,
    pub seat: u8,
    pub kind: ActionKind,
    /// True only when this action exhausts the player's stack.
    pub all_in: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct BoardEvent {
    pub street: Street,
    pub cards: Vec<Card>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Pot {
    /// Gross amount before rake.
    pub amount: Chips,
    pub eligible_seats: Vec<u8>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Award {
    pub pot_index: usize,
    pub seat: u8,
    pub amount: Chips,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Hand {
    pub game: GameDefinition,
    pub provenance: Provenance,
    pub table_name: String,
    pub played_at: String,
    pub players: Vec<PlayerAtSeat>,
    pub actions: Vec<ActionEvent>,
    pub board: Vec<BoardEvent>,
    pub pots: Vec<Pot>,
    pub awards: Vec<Award>,
    pub rake: Chips,
    /// Seat holding the dealer button. It may be unoccupied (a dead button).
    /// `None` means the source did not say, so positions cannot be derived;
    /// hands stored before this field existed deserialize to `None`.
    #[serde(default)]
    pub button_seat: Option<u8>,
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum HandError {
    #[error("invalid game or player definition")]
    InvalidDefinition,
    #[error("duplicate seat or unknown actor")]
    InvalidSeat,
    #[error("duplicate known card")]
    DuplicateCard,
    #[error("action sequence or street order is invalid")]
    ActionOrder,
    #[error("folded or all-in player acted again")]
    InactivePlayer,
    #[error("invalid chip amount or stack below zero")]
    InvalidAmount,
    #[error("uncalled contribution has no matching return")]
    UncalledContribution,
    #[error("declared pots do not match contributions and eligibility")]
    PotMismatch,
    #[error("award is ineligible or exceeds its pot")]
    InvalidAward,
    #[error("contributions do not equal awards plus rake")]
    Conservation,
}

fn street_index(street: Street) -> u8 {
    match street {
        Street::Preflop => 0,
        Street::Flop => 1,
        Street::Turn => 2,
        Street::River => 3,
        Street::Showdown => 4,
    }
}

/// Validate stated facts without supplying missing payouts or cards.
pub fn validate_hand(hand: &Hand) -> Result<(), HandError> {
    let g = &hand.game;
    if g.currency.is_empty()
        || g.currency_scale > 6
        || g.small_blind.0 <= 0
        || g.big_blind.0 <= g.small_blind.0
        || g.ante.0 < 0
        || !(2..=10).contains(&g.table_capacity)
        || hand.players.len() < 2
        || hand.players.len() > usize::from(g.table_capacity)
        || hand.actions.is_empty()
        || hand.pots.is_empty()
        || hand.provenance.room.is_empty()
        || hand.provenance.external_hand_id.is_empty()
        || hand.provenance.parser_version.is_empty()
    {
        return Err(HandError::InvalidDefinition);
    }
    if hand
        .button_seat
        .is_some_and(|seat| seat == 0 || seat > g.table_capacity)
    {
        return Err(HandError::InvalidSeat);
    }
    let mut seats = BTreeMap::new();
    let mut cards = Vec::new();
    for player in &hand.players {
        if player.seat == 0
            || player.seat > g.table_capacity
            || player.name.is_empty()
            || player.starting_stack.0 < 0
            || seats.insert(player.seat, player.starting_stack.0).is_some()
        {
            return Err(HandError::InvalidSeat);
        }
        if let Some(hole) = player.hole_cards {
            cards.extend(hole.into_iter().flatten());
        }
    }
    let mut last_board_street = 0;
    for event in &hand.board {
        let index = street_index(event.street);
        if index == 0
            || index == 4
            || index != last_board_street + 1
            || event.cards.len() != if index == 1 { 3 } else { 1 }
        {
            return Err(HandError::ActionOrder);
        }
        last_board_street = index;
        cards.extend(event.cards.iter().copied());
    }
    validate_unique_cards(&cards).map_err(|_| HandError::DuplicateCard)?;

    let mut stacks = seats.clone();
    let mut totals: BTreeMap<u8, i64> = seats.keys().map(|seat| (*seat, 0)).collect();
    let mut street_totals = totals.clone();
    let mut folded = BTreeSet::new();
    let mut all_in = BTreeSet::new();
    let mut last_street = 0;
    for (position, event) in hand.actions.iter().enumerate() {
        if event.sequence != position as u32 || !seats.contains_key(&event.seat) {
            return Err(HandError::ActionOrder);
        }
        let street = street_index(event.street);
        if street == 4 || street < last_street {
            return Err(HandError::ActionOrder);
        }
        if street > last_street {
            street_totals.values_mut().for_each(|amount| *amount = 0);
            last_street = street;
        }
        let is_return = matches!(event.kind, ActionKind::ReturnUncalled { .. });
        if matches!(
            event.kind,
            ActionKind::PostSmallBlind { .. }
                | ActionKind::PostBigBlind { .. }
                | ActionKind::PostAnte { .. }
        ) && event.street != Street::Preflop
        {
            return Err(HandError::ActionOrder);
        }
        if folded.contains(&event.seat) || (all_in.contains(&event.seat) && !is_return) {
            return Err(HandError::InactivePlayer);
        }
        let current = *street_totals
            .get(&event.seat)
            .ok_or(HandError::InvalidSeat)?;
        let highest = street_totals.values().copied().max().unwrap_or(0);
        let outstanding = highest
            .checked_sub(current)
            .ok_or(HandError::InvalidAmount)?;
        let delta = match event.kind {
            ActionKind::Fold | ActionKind::Check => 0,
            ActionKind::Call { amount_added }
            | ActionKind::Bet { amount_added }
            | ActionKind::PostSmallBlind { amount_added }
            | ActionKind::PostBigBlind { amount_added }
            | ActionKind::PostAnte { amount_added } => amount_added.0,
            ActionKind::RaiseTo {
                total_street_contribution,
            } => total_street_contribution
                .0
                .checked_sub(current)
                .ok_or(HandError::InvalidAmount)?,
            ActionKind::ReturnUncalled { amount } => -amount.0,
        };
        match event.kind {
            ActionKind::Check if outstanding != 0 => return Err(HandError::InvalidAmount),
            ActionKind::Call { .. }
                if outstanding == 0
                    || delta > outstanding
                    || (delta < outstanding && !event.all_in) =>
            {
                return Err(HandError::InvalidAmount);
            }
            ActionKind::Bet { .. } if highest != 0 => return Err(HandError::InvalidAmount),
            ActionKind::RaiseTo {
                total_street_contribution,
            } if highest == 0 || total_street_contribution.0 <= highest => {
                return Err(HandError::InvalidAmount);
            }
            _ => {}
        }
        if is_return {
            let opposing_max = street_totals
                .iter()
                .filter(|(seat, _)| **seat != event.seat)
                .map(|(_, amount)| *amount)
                .max()
                .unwrap_or(0);
            if current <= opposing_max || -delta != current - opposing_max || event.all_in {
                return Err(HandError::InvalidAmount);
            }
        }
        if matches!(event.kind, ActionKind::Check | ActionKind::Fold) && event.all_in {
            return Err(HandError::InvalidAmount);
        }
        if !matches!(event.kind, ActionKind::Check | ActionKind::Fold) && delta == 0 {
            return Err(HandError::InvalidAmount);
        }
        let new_street = current.checked_add(delta).ok_or(HandError::InvalidAmount)?;
        let new_total = totals[&event.seat]
            .checked_add(delta)
            .ok_or(HandError::InvalidAmount)?;
        let new_stack = stacks[&event.seat]
            .checked_sub(delta)
            .ok_or(HandError::InvalidAmount)?;
        if new_street < 0
            || new_total < 0
            || new_stack < 0
            || (event.all_in != (new_stack == 0) && !is_return)
        {
            return Err(HandError::InvalidAmount);
        }
        street_totals.insert(
            event.seat,
            if matches!(event.kind, ActionKind::PostAnte { .. }) {
                current
            } else {
                new_street
            },
        );
        totals.insert(event.seat, new_total);
        stacks.insert(event.seat, new_stack);
        if matches!(event.kind, ActionKind::Fold) {
            folded.insert(event.seat);
        }
        if event.all_in {
            all_in.insert(event.seat);
        }
    }
    let mut levels: Vec<i64> = totals
        .values()
        .copied()
        .filter(|value| *value > 0)
        .collect();
    levels.sort_unstable();
    levels.dedup();
    let mut lower = 0i64;
    let mut computed = Vec::new();
    for upper in levels {
        let contributors: Vec<_> = totals
            .iter()
            .filter(|(_, value)| **value >= upper)
            .map(|(seat, _)| *seat)
            .collect();
        if contributors.len() < 2 {
            return Err(HandError::UncalledContribution);
        }
        let amount = (upper - lower)
            .checked_mul(contributors.len() as i64)
            .ok_or(HandError::InvalidAmount)?;
        let eligible_seats: Vec<_> = contributors
            .into_iter()
            .filter(|seat| !folded.contains(seat))
            .collect();
        if eligible_seats.is_empty() {
            return Err(HandError::PotMismatch);
        }
        computed.push(Pot {
            amount: Chips(amount),
            eligible_seats,
        });
        lower = upper;
    }
    if computed != hand.pots {
        return Err(HandError::PotMismatch);
    }
    if hand.rake.0 < 0 {
        return Err(HandError::InvalidAmount);
    }
    let mut remaining: Vec<i64> = hand.pots.iter().map(|pot| pot.amount.0).collect();
    for award in &hand.awards {
        let pot = hand
            .pots
            .get(award.pot_index)
            .ok_or(HandError::InvalidAward)?;
        if award.amount.0 <= 0 || !pot.eligible_seats.contains(&award.seat) {
            return Err(HandError::InvalidAward);
        }
        let balance = remaining
            .get_mut(award.pot_index)
            .ok_or(HandError::InvalidAward)?;
        *balance = balance
            .checked_sub(award.amount.0)
            .ok_or(HandError::InvalidAmount)?;
        if *balance < 0 {
            return Err(HandError::InvalidAward);
        }
    }
    let unpaid = remaining
        .into_iter()
        .try_fold(0i64, |sum, amount| sum.checked_add(amount))
        .ok_or(HandError::InvalidAmount)?;
    if unpaid != hand.rake.0 {
        return Err(HandError::Conservation);
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{Rank, Suit};

    fn card(rank: Rank, suit: Suit) -> Card {
        Card { rank, suit }
    }

    fn golden_hand() -> Hand {
        let action = |sequence, seat, kind, all_in| ActionEvent {
            sequence,
            street: Street::Preflop,
            seat,
            kind,
            all_in,
        };
        Hand {
            game: GameDefinition {
                variant: GameVariant::NoLimitHoldem,
                currency: "USD".into(),
                currency_scale: 2,
                small_blind: Chips(1),
                big_blind: Chips(2),
                ante: Chips(0),
                table_capacity: 6,
            },
            provenance: Provenance {
                room: "synthetic-stars-like".into(),
                external_hand_id: "1001".into(),
                parser_version: "0.1.0".into(),
                source_sha256: "fixture".into(),
                start_line: 1,
                end_line: 27,
            },
            table_name: "Example".into(),
            played_at: "2026-10-23T12:00:00Z".into(),
            players: vec![
                PlayerAtSeat {
                    seat: 1,
                    name: "Ada".into(),
                    starting_stack: Chips(100),
                    hole_cards: Some([
                        Some(card(Rank::Ace, Suit::Spades)),
                        Some(card(Rank::Ace, Suit::Hearts)),
                    ]),
                },
                PlayerAtSeat {
                    seat: 2,
                    name: "Bo".into(),
                    starting_stack: Chips(200),
                    hole_cards: Some([
                        Some(card(Rank::King, Suit::Clubs)),
                        Some(card(Rank::King, Suit::Diamonds)),
                    ]),
                },
                PlayerAtSeat {
                    seat: 3,
                    name: "Cy".into(),
                    starting_stack: Chips(300),
                    hole_cards: Some([
                        Some(card(Rank::Queen, Suit::Spades)),
                        Some(card(Rank::Queen, Suit::Hearts)),
                    ]),
                },
            ],
            actions: vec![
                action(
                    0,
                    1,
                    ActionKind::PostSmallBlind {
                        amount_added: Chips(1),
                    },
                    false,
                ),
                action(
                    1,
                    2,
                    ActionKind::PostBigBlind {
                        amount_added: Chips(2),
                    },
                    false,
                ),
                action(
                    2,
                    3,
                    ActionKind::RaiseTo {
                        total_street_contribution: Chips(300),
                    },
                    true,
                ),
                action(
                    3,
                    1,
                    ActionKind::Call {
                        amount_added: Chips(99),
                    },
                    true,
                ),
                action(
                    4,
                    2,
                    ActionKind::Call {
                        amount_added: Chips(198),
                    },
                    true,
                ),
                action(
                    5,
                    3,
                    ActionKind::ReturnUncalled { amount: Chips(100) },
                    false,
                ),
            ],
            board: vec![
                BoardEvent {
                    street: Street::Flop,
                    cards: vec![
                        card(Rank::Two, Suit::Clubs),
                        card(Rank::Seven, Suit::Diamonds),
                        card(Rank::Nine, Suit::Hearts),
                    ],
                },
                BoardEvent {
                    street: Street::Turn,
                    cards: vec![card(Rank::Jack, Suit::Spades)],
                },
                BoardEvent {
                    street: Street::River,
                    cards: vec![card(Rank::Three, Suit::Clubs)],
                },
            ],
            pots: vec![
                Pot {
                    amount: Chips(300),
                    eligible_seats: vec![1, 2, 3],
                },
                Pot {
                    amount: Chips(200),
                    eligible_seats: vec![2, 3],
                },
            ],
            awards: vec![
                Award {
                    pot_index: 0,
                    seat: 1,
                    amount: Chips(300),
                },
                Award {
                    pot_index: 1,
                    seat: 2,
                    amount: Chips(200),
                },
            ],
            rake: Chips(0),
            button_seat: Some(1),
        }
    }

    #[test]
    fn golden_side_pot_and_return_reconcile() {
        let hand = golden_hand();
        assert_eq!(validate_hand(&hand), Ok(()));
        assert_eq!(hand.pots.iter().map(|pot| pot.amount.0).sum::<i64>(), 500);
        assert_eq!(
            hand.awards.iter().map(|award| award.amount.0).sum::<i64>(),
            500
        );
    }

    #[test]
    fn rejects_invented_or_ineligible_payouts() {
        let mut hand = golden_hand();
        hand.awards[1].seat = 1;
        assert_eq!(validate_hand(&hand), Err(HandError::InvalidAward));
        hand = golden_hand();
        hand.awards[1].amount = Chips(199);
        assert_eq!(validate_hand(&hand), Err(HandError::Conservation));
        hand = golden_hand();
        hand.actions.pop();
        assert_eq!(validate_hand(&hand), Err(HandError::UncalledContribution));
    }

    #[test]
    fn rejects_invalid_actions_and_stacks() {
        let mut hand = golden_hand();
        hand.actions.push(ActionEvent {
            sequence: 6,
            street: Street::Preflop,
            seat: 1,
            kind: ActionKind::Check,
            all_in: false,
        });
        assert_eq!(validate_hand(&hand), Err(HandError::InactivePlayer));
        hand = golden_hand();
        hand.actions[3].kind = ActionKind::Call {
            amount_added: Chips(100),
        };
        assert_eq!(validate_hand(&hand), Err(HandError::InvalidAmount));
        hand = golden_hand();
        hand.actions[4].sequence = 7;
        assert_eq!(validate_hand(&hand), Err(HandError::ActionOrder));
        hand = golden_hand();
        hand.actions[5].kind = ActionKind::ReturnUncalled { amount: Chips(99) };
        assert_eq!(validate_hand(&hand), Err(HandError::InvalidAmount));
    }

    #[test]
    fn rejects_duplicate_known_cards() {
        let mut hand = golden_hand();
        let card = Card {
            rank: Rank::Ace,
            suit: Suit::Spades,
        };
        hand.players[0].hole_cards = Some([Some(card), None]);
        hand.players[1].hole_cards = Some([None, Some(card)]);
        assert_eq!(validate_hand(&hand), Err(HandError::DuplicateCard));
    }
}
