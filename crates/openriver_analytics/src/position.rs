//! Table positions derived from the button and the blinds actually posted.

use std::collections::BTreeMap;

/// A player's seat relative to the dealer button.
///
/// Early seats are named from the first to act: the first seat is always
/// `Utg` (unless it is the only one, which is then `Cutoff`); the last three non-blind, non-button seats are `Cutoff`, `Hijack`
/// and `Lojack` (counting back from the button); any seats in between are
/// `Utg1`, `Utg2`, ... in action order. Heads-up, the button posts the small
/// blind and is reported as `Button`.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum Position {
    SmallBlind,
    BigBlind,
    Utg,
    Utg1,
    Utg2,
    Utg3,
    Lojack,
    Hijack,
    Cutoff,
    Button,
}

/// Coarse grouping for filters and summary tables.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum PositionGroup {
    Early,
    Middle,
    Late,
    Blinds,
}

impl Position {
    pub fn group(self) -> PositionGroup {
        match self {
            Self::SmallBlind | Self::BigBlind => PositionGroup::Blinds,
            Self::Utg | Self::Utg1 | Self::Utg2 | Self::Utg3 => PositionGroup::Early,
            Self::Lojack | Self::Hijack => PositionGroup::Middle,
            Self::Cutoff | Self::Button => PositionGroup::Late,
        }
    }

    /// Positions from which a first-in raise is conventionally a steal attempt.
    pub fn is_steal_position(self) -> bool {
        matches!(self, Self::Cutoff | Self::Button | Self::SmallBlind)
    }
}

/// Assign positions to every seat that was dealt in.
///
/// `occupied` must contain the seats dealt in and `small_blind`/`big_blind`
/// must be among them. Returns `None` when the blinds coincide, which no valid
/// hand can produce. A dead button (an unoccupied button seat) leaves no
/// `Button` player; the remaining seats are then labelled as if the last of
/// them acted just before the small blind.
pub fn assign_positions(
    occupied: &[u8],
    button: Option<u8>,
    small_blind: u8,
    big_blind: u8,
) -> Option<BTreeMap<u8, Position>> {
    if small_blind == big_blind
        || !occupied.contains(&small_blind)
        || !occupied.contains(&big_blind)
    {
        return None;
    }
    let mut seats = occupied.to_vec();
    seats.sort_unstable();
    seats.dedup();
    let big_index = seats.iter().position(|seat| *seat == big_blind)?;
    // Seats in preflop action order after the big blind: UTG ... then the blinds.
    let mut order: Vec<u8> = (1..seats.len())
        .map(|offset| seats[(big_index + offset) % seats.len()])
        .collect();
    // The small blind acts last before the big blind in the order above.
    order.retain(|seat| *seat != small_blind);
    let mut positions = BTreeMap::new();
    positions.insert(small_blind, Position::SmallBlind);
    positions.insert(big_blind, Position::BigBlind);
    let heads_up = seats.len() == 2;
    if heads_up {
        // The button posts the small blind heads-up.
        if button == Some(small_blind) {
            positions.insert(small_blind, Position::Button);
        }
        return Some(positions);
    }
    let mut early = order;
    if let (Some(button), Some(last)) = (button, early.last().copied()) {
        if last == button {
            positions.insert(button, Position::Button);
            early.pop();
        }
    }
    const LATE: [Position; 3] = [Position::Cutoff, Position::Hijack, Position::Lojack];
    const MIDDLE: [Position; 3] = [Position::Utg1, Position::Utg2, Position::Utg3];
    let count = early.len();
    if count == 1 {
        positions.insert(early[0], Position::Cutoff);
        early.clear();
    }
    // First seat is UTG, then up to three late labels from the end, rest in between.
    let late_count = count.saturating_sub(1).min(LATE.len());
    for (index, seat) in early.iter().enumerate() {
        let position = if index == 0 {
            Position::Utg
        } else if index >= count - late_count {
            LATE[count - 1 - index]
        } else {
            MIDDLE[(index - 1).min(MIDDLE.len() - 1)]
        };
        positions.insert(*seat, position);
    }
    Some(positions)
}

#[cfg(test)]
mod tests {
    use super::*;
    use Position::*;

    fn layout(seats: &[u8], button: u8, sb: u8, bb: u8) -> Vec<(u8, Position)> {
        assign_positions(seats, Some(button), sb, bb)
            .unwrap()
            .into_iter()
            .collect()
    }

    #[test]
    fn six_max_with_wrapping_seats() {
        assert_eq!(
            layout(&[1, 2, 3, 4, 5, 6], 4, 5, 6),
            vec![
                (1, Utg),
                (2, Hijack),
                (3, Cutoff),
                (4, Button),
                (5, SmallBlind),
                (6, BigBlind)
            ]
        );
        // The button at seat 6 makes seat 1 the small blind and 2 the big blind.
        assert_eq!(
            layout(&[1, 2, 3, 4, 5, 6], 6, 1, 2),
            vec![
                (1, SmallBlind),
                (2, BigBlind),
                (3, Utg),
                (4, Hijack),
                (5, Cutoff),
                (6, Button)
            ]
        );
    }

    #[test]
    fn full_ring_names_every_seat_once() {
        let seats: Vec<u8> = (1..=9).collect();
        let got = layout(&seats, 9, 1, 2);
        let names: Vec<_> = got.iter().map(|(_, p)| *p).collect();
        assert_eq!(
            names,
            vec![SmallBlind, BigBlind, Utg, Utg1, Utg2, Lojack, Hijack, Cutoff, Button]
        );
        let ten: Vec<u8> = (1..=10).collect();
        let got = layout(&ten, 10, 1, 2);
        assert_eq!(got[4].1, Utg2);
        assert_eq!(got[5].1, Utg3);
    }

    #[test]
    fn short_handed_tables() {
        assert_eq!(
            layout(&[2, 5, 7], 7, 2, 5),
            vec![(2, SmallBlind), (5, BigBlind), (7, Button)]
        );
        assert_eq!(
            layout(&[1, 3, 4, 8], 4, 8, 1),
            vec![(1, BigBlind), (3, Cutoff), (4, Button), (8, SmallBlind)]
        );
    }

    #[test]
    fn heads_up_button_is_the_small_blind() {
        assert_eq!(layout(&[3, 6], 3, 3, 6), vec![(3, Button), (6, BigBlind)]);
    }

    #[test]
    fn dead_button_leaves_no_button_player() {
        // Seat 4 holds the button but is empty; seats 5 and 6 are the blinds.
        let got = layout(&[1, 2, 3, 5, 6], 4, 5, 6);
        assert!(got.iter().all(|(_, p)| *p != Button));
        assert_eq!(got.len(), 5);
    }

    #[test]
    fn unknown_button_still_labels_without_a_button() {
        let got = assign_positions(&[1, 2, 3, 4], None, 3, 4).unwrap();
        assert!(got.values().all(|p| *p != Button));
        assert_eq!(got[&3], SmallBlind);
        assert_eq!(got[&1], Utg);
    }

    #[test]
    fn rejects_inconsistent_blinds() {
        assert!(assign_positions(&[1, 2, 3], Some(1), 2, 2).is_none());
        assert!(assign_positions(&[1, 2, 3], Some(1), 2, 9).is_none());
    }
}
