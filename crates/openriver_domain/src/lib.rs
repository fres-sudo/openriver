//! Canonical poker value types. No UI, I/O, or persistence dependencies.

use serde::{Deserialize, Serialize};
use thiserror::Error;

/// Integer accounting units. Currency precision belongs to the game definition.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Chips(pub i64);

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Suit {
    Clubs,
    Diamonds,
    Hearts,
    Spades,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Rank {
    Two,
    Three,
    Four,
    Five,
    Six,
    Seven,
    Eight,
    Nine,
    Ten,
    Jack,
    Queen,
    King,
    Ace,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct Card {
    pub rank: Rank,
    pub suit: Suit,
}

#[derive(Debug, Error, PartialEq, Eq)]
pub enum CardError {
    #[error("a known card appears more than once")]
    DuplicateCard,
}

pub fn validate_unique_cards(cards: &[Card]) -> Result<(), CardError> {
    let mut seen = std::collections::HashSet::with_capacity(cards.len());
    for card in cards {
        if !seen.insert(card) {
            return Err(CardError::DuplicateCard);
        }
    }
    Ok(())
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum Street {
    Preflop,
    Flop,
    Turn,
    River,
    Showdown,
}

/// Raise-to is the total contribution on this street, never a delta.
/// These are event types, not a betting-state validator.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum ActionKind {
    Fold,
    Check,
    Call { amount_added: Chips },
    Bet { amount_added: Chips },
    RaiseTo { total_street_contribution: Chips },
    ReturnUncalled { amount: Chips },
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_duplicate_known_cards() {
        let ace = Card {
            rank: Rank::Ace,
            suit: Suit::Spades,
        };
        assert_eq!(
            validate_unique_cards(&[ace, ace]),
            Err(CardError::DuplicateCard)
        );
        assert_eq!(
            validate_unique_cards(&[
                ace,
                Card {
                    suit: Suit::Hearts,
                    ..ace
                }
            ]),
            Ok(())
        );
    }
}
