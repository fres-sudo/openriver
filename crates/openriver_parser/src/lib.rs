//! Strict parser for the documented synthetic PokerStars-like cash format.

use openriver_domain::{
    validate_hand, ActionEvent, ActionKind, Award, BoardEvent, Card, Chips, GameDefinition,
    GameVariant, Hand, PlayerAtSeat, Pot, Provenance, Rank, Street, Suit,
};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::{BTreeMap, BTreeSet};
use thiserror::Error;

pub const MAX_SOURCE_BYTES: usize = 32 * 1024 * 1024;
pub const MAX_LINE_BYTES: usize = 4096;
pub const MAX_HANDS: usize = 10_000;
pub const PARSER_VERSION: &str = env!("CARGO_PKG_VERSION");

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum Severity {
    Warning,
    Error,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum DiagnosticCode {
    UnsupportedFormat,
    IncompleteHand,
    MalformedField,
    InvalidHand,
    DuplicateHandId,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ParseDiagnostic {
    pub source_hand_id: Option<String>,
    pub start_line: usize,
    pub end_line: usize,
    pub severity: Severity,
    pub code: DiagnosticCode,
    pub parser_version: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ParseResult {
    pub hands: Vec<Hand>,
    pub diagnostics: Vec<ParseDiagnostic>,
    pub parser_version: String,
}

#[derive(Debug, Error, PartialEq, Eq)]
pub enum ImportError {
    #[error("hand history is empty")]
    EmptySource,
    #[error("hand history exceeds the 32 MiB limit")]
    SourceTooLarge,
    #[error("hand history must be UTF-8")]
    InvalidEncoding,
    #[error("hand history has too many hands or an overlong line")]
    SourceLimit,
    #[error("unsupported hand-history format")]
    UnsupportedFormat,
}

pub fn preflight(source: &[u8]) -> Result<&str, ImportError> {
    if source.len() > MAX_SOURCE_BYTES {
        return Err(ImportError::SourceTooLarge);
    }
    let text = std::str::from_utf8(source).map_err(|_| ImportError::InvalidEncoding)?;
    if text.trim().is_empty() {
        return Err(ImportError::EmptySource);
    }
    if text.lines().any(|line| line.len() > MAX_LINE_BYTES) {
        return Err(ImportError::SourceLimit);
    }
    Ok(text)
}

fn diagnostic(
    id: Option<String>,
    start: usize,
    end: usize,
    code: DiagnosticCode,
) -> ParseDiagnostic {
    ParseDiagnostic {
        source_hand_id: id,
        start_line: start,
        end_line: end,
        severity: Severity::Error,
        code,
        parser_version: PARSER_VERSION.into(),
    }
}

/// Each supported header starts an independent hand; one bad span cannot discard its neighbors.
pub fn parse(source: &[u8]) -> Result<ParseResult, ImportError> {
    let text = preflight(source)?;
    let lines: Vec<&str> = text.lines().collect();
    let starts: Vec<usize> = lines
        .iter()
        .enumerate()
        .filter_map(|(i, line)| line.starts_with("PokerStars Hand #").then_some(i))
        .collect();
    if starts.is_empty()
        || lines[..starts[0]]
            .iter()
            .any(|line| !line.trim().is_empty())
    {
        return Err(ImportError::UnsupportedFormat);
    }
    if starts.len() > MAX_HANDS {
        return Err(ImportError::SourceLimit);
    }
    let hash = format!("{:x}", Sha256::digest(source));
    let mut result = ParseResult {
        hands: Vec::new(),
        diagnostics: Vec::new(),
        parser_version: PARSER_VERSION.into(),
    };
    let mut seen = BTreeSet::new();
    for (index, &start) in starts.iter().enumerate() {
        let end = starts.get(index + 1).copied().unwrap_or(lines.len());
        let span = &lines[start..end];
        let id = span[0]
            .strip_prefix("PokerStars Hand #")
            .and_then(|rest| rest.split_once(':'))
            .map(|(id, _)| id.to_owned());
        let outcome = parse_hand(span, start + 1, end, &hash);
        match outcome {
            Ok(hand) if !seen.insert(hand.provenance.external_hand_id.clone()) => {
                result.diagnostics.push(diagnostic(
                    id,
                    start + 1,
                    end,
                    DiagnosticCode::DuplicateHandId,
                ))
            }
            Ok(hand) => result.hands.push(hand),
            Err(code) => result
                .diagnostics
                .push(diagnostic(id, start + 1, end, code)),
        }
    }
    Ok(result)
}

fn amount(text: &str) -> Option<i64> {
    let text = text.strip_prefix('$')?;
    let (whole, cents) = text.split_once('.')?;
    if whole.is_empty()
        || cents.len() != 2
        || !whole.bytes().all(|c| c.is_ascii_digit())
        || !cents.bytes().all(|c| c.is_ascii_digit())
    {
        return None;
    }
    whole
        .parse::<i64>()
        .ok()?
        .checked_mul(100)?
        .checked_add(cents.parse::<i64>().ok()?)
}

fn card(text: &str) -> Option<Card> {
    let mut chars = text.chars();
    let rank = match chars.next()? {
        '2' => Rank::Two,
        '3' => Rank::Three,
        '4' => Rank::Four,
        '5' => Rank::Five,
        '6' => Rank::Six,
        '7' => Rank::Seven,
        '8' => Rank::Eight,
        '9' => Rank::Nine,
        'T' => Rank::Ten,
        'J' => Rank::Jack,
        'Q' => Rank::Queen,
        'K' => Rank::King,
        'A' => Rank::Ace,
        _ => return None,
    };
    let suit = match chars.next()? {
        'c' => Suit::Clubs,
        'd' => Suit::Diamonds,
        'h' => Suit::Hearts,
        's' => Suit::Spades,
        _ => return None,
    };
    if chars.next().is_some() {
        return None;
    }
    Some(Card { rank, suit })
}

fn bracket_cards(text: &str) -> Option<Vec<Card>> {
    text.split_whitespace().map(card).collect()
}

fn seat_for(name: &str, players: &[PlayerAtSeat]) -> Option<u8> {
    players
        .iter()
        .find(|player| player.name == name)
        .map(|player| player.seat)
}

fn parse_hand(
    lines: &[&str],
    start: usize,
    end: usize,
    hash: &str,
) -> Result<Hand, DiagnosticCode> {
    let malformed = DiagnosticCode::MalformedField;
    let header = lines[0]
        .strip_prefix("PokerStars Hand #")
        .ok_or(malformed)?;
    let (id, rest) = header.split_once(": Hold'em No Limit (").ok_or(malformed)?;
    if id.is_empty() || !id.bytes().all(|c| c.is_ascii_digit()) {
        return Err(malformed);
    }
    let (stakes, date) = rest.split_once(") - ").ok_or(malformed)?;
    let (blind_text, currency) = stakes.split_once(' ').ok_or(malformed)?;
    if currency != "USD" {
        return Err(DiagnosticCode::UnsupportedFormat);
    }
    let (small, big) = blind_text.split_once('/').ok_or(malformed)?;
    let small = amount(small).ok_or(malformed)?;
    let big = amount(big).ok_or(malformed)?;
    let played_at = date
        .strip_suffix(" UTC")
        .ok_or(malformed)?
        .replace('/', "-")
        .replace(' ', "T")
        + "Z";
    let table_line = lines.get(1).ok_or(DiagnosticCode::IncompleteHand)?;
    let table = table_line
        .strip_prefix("Table '")
        .and_then(|v| v.split_once("' "))
        .ok_or(malformed)?;
    let capacity = table
        .1
        .split_once("-max Seat #")
        .ok_or(malformed)?
        .0
        .parse::<u8>()
        .map_err(|_| malformed)?;
    let mut hand = Hand {
        game: GameDefinition {
            variant: GameVariant::NoLimitHoldem,
            currency: currency.into(),
            currency_scale: 2,
            small_blind: Chips(small),
            big_blind: Chips(big),
            ante: Chips(0),
            table_capacity: capacity,
        },
        provenance: Provenance {
            room: "synthetic-stars-like".into(),
            external_hand_id: id.into(),
            parser_version: PARSER_VERSION.into(),
            source_sha256: hash.into(),
            start_line: start,
            end_line: end,
        },
        table_name: table.0.into(),
        played_at,
        players: Vec::new(),
        actions: Vec::new(),
        board: Vec::new(),
        pots: Vec::new(),
        awards: Vec::new(),
        rake: Chips(0),
    };
    let mut cursor = 2;
    while let Some(line) = lines.get(cursor).copied() {
        let Some(seat_line) = line.strip_prefix("Seat ") else {
            break;
        };
        let (seat, rest) = seat_line.split_once(": ").ok_or(malformed)?;
        let (name, stack) = rest.split_once(" ($").ok_or(malformed)?;
        if hand.players.iter().any(|player| player.name == name) {
            return Err(DiagnosticCode::InvalidHand);
        }
        let stack = stack.strip_suffix(" in chips)").ok_or(malformed)?;
        let stack = amount(&format!("${stack}")).ok_or(malformed)?;
        hand.players.push(PlayerAtSeat {
            seat: seat.parse().map_err(|_| malformed)?,
            name: name.into(),
            starting_stack: Chips(stack),
            hole_cards: None,
        });
        cursor += 1;
    }
    if hand.players.len() < 2 {
        return Err(malformed);
    }
    let mut street = Street::Preflop;
    let mut in_summary = false;
    let mut saw_summary = false;
    let mut declared_total = None;
    let mut declared_pots = Vec::new();
    let mut summary_awards = BTreeMap::new();
    let mut collected = Vec::new();
    let mut disclosed_players = BTreeSet::new();
    let mut ante_seats = BTreeSet::new();
    let mut saw_hole_cards = false;
    let mut small_blind_seat = None;
    let mut big_blind_seat = None;
    let mut stated_raises = BTreeMap::new();
    for &raw in &lines[cursor..] {
        let line = raw.trim();
        if line.is_empty() {
            continue;
        }
        if line == "*** SUMMARY ***" {
            if saw_summary {
                return Err(malformed);
            }
            in_summary = true;
            saw_summary = true;
            continue;
        }
        if in_summary {
            if let Some(rest) = line.strip_prefix("Total pot $") {
                if declared_total.is_some() {
                    return Err(malformed);
                }
                let (total, rake) = rest.split_once(" | Rake $").ok_or(malformed)?;
                declared_total = Some(amount(&format!("${total}")).ok_or(malformed)?);
                hand.rake = Chips(amount(&format!("${rake}")).ok_or(malformed)?);
            } else if line.starts_with("Main pot $") || line.starts_with("Side pot $") {
                let (label, rest) = line.split_once(" $").ok_or(malformed)?;
                let (value, winner) = rest.split_once(" won by ").ok_or(malformed)?;
                declared_pots.push((
                    label.to_owned(),
                    amount(&format!("${value}")).ok_or(malformed)?,
                    seat_for(winner, &hand.players).ok_or(malformed)?,
                ));
            } else if let Some(rest) = line.strip_prefix("Seat ") {
                let (seat, rest) = rest.split_once(": ").ok_or(malformed)?;
                let (name, value) = rest.split_once(" collected ").ok_or(malformed)?;
                let seat = seat.parse::<u8>().map_err(|_| malformed)?;
                if seat_for(name, &hand.players) != Some(seat)
                    || summary_awards
                        .insert(seat, amount(value).ok_or(malformed)?)
                        .is_some()
                {
                    return Err(malformed);
                }
            } else {
                return Err(malformed);
            }
            continue;
        }
        if line == "*** HOLE CARDS ***" {
            if saw_hole_cards {
                return Err(DiagnosticCode::InvalidHand);
            }
            saw_hole_cards = true;
            continue;
        }
        if line == "*** SHOW DOWN ***" {
            if !saw_hole_cards {
                return Err(DiagnosticCode::InvalidHand);
            }
            continue;
        }
        if let Some(rest) = line.strip_prefix("*** FLOP *** [") {
            if !saw_hole_cards {
                return Err(DiagnosticCode::InvalidHand);
            }
            let cards = rest
                .strip_suffix(']')
                .and_then(bracket_cards)
                .ok_or(malformed)?;
            hand.board.push(BoardEvent {
                street: Street::Flop,
                cards,
            });
            street = Street::Flop;
            continue;
        }
        if let Some(rest) = line
            .strip_prefix("*** TURN *** [")
            .or_else(|| line.strip_prefix("*** RIVER *** ["))
        {
            let next = if line.starts_with("*** TURN") {
                Street::Turn
            } else {
                Street::River
            };
            let (previous, new) = rest.split_once("] [").ok_or(malformed)?;
            let previous = bracket_cards(previous).ok_or(malformed)?;
            let known_board: Vec<Card> = hand
                .board
                .iter()
                .flat_map(|event| event.cards.iter().copied())
                .collect();
            if previous != known_board {
                return Err(DiagnosticCode::InvalidHand);
            }
            let cards = new
                .strip_suffix(']')
                .and_then(bracket_cards)
                .ok_or(malformed)?;
            hand.board.push(BoardEvent {
                street: next,
                cards,
            });
            street = next;
            continue;
        }
        if let Some(rest) = line.strip_prefix("Uncalled bet ($") {
            let (value, name) = rest.split_once(") returned to ").ok_or(malformed)?;
            let seat = seat_for(name, &hand.players).ok_or(malformed)?;
            hand.actions.push(ActionEvent {
                sequence: hand.actions.len() as u32,
                street,
                seat,
                kind: ActionKind::ReturnUncalled {
                    amount: Chips(amount(&format!("${value}")).ok_or(malformed)?),
                },
                all_in: false,
            });
            continue;
        }
        if let Some((name, rest)) = line.split_once(": shows [") {
            let seat = seat_for(name, &hand.players).ok_or(malformed)?;
            if !disclosed_players.insert(seat) {
                return Err(DiagnosticCode::InvalidHand);
            }
            let (cards, _) = rest.split_once(']').ok_or(malformed)?;
            let cards = bracket_cards(cards).ok_or(malformed)?;
            if cards.len() != 2 {
                return Err(malformed);
            }
            let player = hand
                .players
                .iter_mut()
                .find(|p| p.name == name)
                .ok_or(malformed)?;
            player.hole_cards = Some([Some(cards[0]), Some(cards[1])]);
            continue;
        }
        if let Some(name) = line.strip_suffix(": mucks hand") {
            let seat = seat_for(name, &hand.players).ok_or(malformed)?;
            if !disclosed_players.insert(seat) {
                return Err(DiagnosticCode::InvalidHand);
            }
            continue;
        }
        if let Some((name, rest)) = line.split_once(" collected $") {
            let (value, label) = rest.split_once(" from ").ok_or(malformed)?;
            let seat = seat_for(name, &hand.players).ok_or(malformed)?;
            collected.push((
                seat,
                amount(&format!("${value}")).ok_or(malformed)?,
                label.to_owned(),
            ));
            continue;
        }
        let (name, rest) = line.split_once(": ").ok_or(malformed)?;
        let seat = seat_for(name, &hand.players).ok_or(malformed)?;
        let all_in = rest.ends_with(" and is all-in");
        let action = rest.strip_suffix(" and is all-in").unwrap_or(rest);
        let kind = if action == "folds" {
            ActionKind::Fold
        } else if action == "checks" {
            ActionKind::Check
        } else if let Some(v) = action.strip_prefix("posts small blind ") {
            ActionKind::PostSmallBlind {
                amount_added: Chips(amount(v).ok_or(malformed)?),
            }
        } else if let Some(v) = action.strip_prefix("posts big blind ") {
            ActionKind::PostBigBlind {
                amount_added: Chips(amount(v).ok_or(malformed)?),
            }
        } else if let Some(v) = action.strip_prefix("posts the ante ") {
            let a = amount(v).ok_or(malformed)?;
            if !ante_seats.insert(seat) || (hand.game.ante.0 != 0 && hand.game.ante.0 != a) {
                return Err(DiagnosticCode::InvalidHand);
            }
            hand.game.ante = Chips(a);
            ActionKind::PostAnte {
                amount_added: Chips(a),
            }
        } else if let Some(v) = action.strip_prefix("calls ") {
            ActionKind::Call {
                amount_added: Chips(amount(v).ok_or(malformed)?),
            }
        } else if let Some(v) = action.strip_prefix("bets ") {
            ActionKind::Bet {
                amount_added: Chips(amount(v).ok_or(malformed)?),
            }
        } else if let Some(v) = action.strip_prefix("raises ") {
            let (increment, total) = v.split_once(" to ").ok_or(malformed)?;
            stated_raises.insert(
                hand.actions.len() as u32,
                amount(increment).ok_or(malformed)?,
            );
            ActionKind::RaiseTo {
                total_street_contribution: Chips(amount(total).ok_or(malformed)?),
            }
        } else {
            return Err(malformed);
        };
        match &kind {
            ActionKind::PostSmallBlind { amount_added } => {
                if saw_hole_cards
                    || amount_added != &hand.game.small_blind
                    || small_blind_seat.replace(seat).is_some()
                {
                    return Err(DiagnosticCode::InvalidHand);
                }
            }
            ActionKind::PostBigBlind { amount_added } => {
                if saw_hole_cards
                    || amount_added != &hand.game.big_blind
                    || big_blind_seat.replace(seat).is_some()
                {
                    return Err(DiagnosticCode::InvalidHand);
                }
            }
            ActionKind::PostAnte { .. } if saw_hole_cards => {
                return Err(DiagnosticCode::InvalidHand);
            }
            ActionKind::PostAnte { .. } => {}
            _ if !saw_hole_cards => return Err(DiagnosticCode::InvalidHand),
            _ => {}
        }
        hand.actions.push(ActionEvent {
            sequence: hand.actions.len() as u32,
            street,
            seat,
            kind,
            all_in,
        });
    }
    if !saw_hole_cards || !saw_summary || declared_total.is_none() {
        return Err(DiagnosticCode::IncompleteHand);
    }
    if small_blind_seat.is_none() || big_blind_seat.is_none() || small_blind_seat == big_blind_seat
    {
        return Err(DiagnosticCode::InvalidHand);
    }
    if !ante_seats.is_empty() && ante_seats.len() != hand.players.len() {
        return Err(DiagnosticCode::InvalidHand);
    }
    let mut totals: BTreeMap<u8, i64> = hand.players.iter().map(|p| (p.seat, 0)).collect();
    let mut street_totals = totals.clone();
    let mut current_street = Street::Preflop;
    let mut folded = BTreeSet::new();
    for action in &hand.actions {
        if action.street != current_street {
            street_totals.values_mut().for_each(|v| *v = 0);
            current_street = action.street;
        }
        let current = street_totals[&action.seat];
        let highest = street_totals.values().copied().max().unwrap_or(0);
        let delta = match action.kind {
            ActionKind::Fold => {
                folded.insert(action.seat);
                0
            }
            ActionKind::Check => 0,
            ActionKind::Call { amount_added }
            | ActionKind::Bet { amount_added }
            | ActionKind::PostSmallBlind { amount_added }
            | ActionKind::PostBigBlind { amount_added }
            | ActionKind::PostAnte { amount_added } => amount_added.0,
            ActionKind::RaiseTo {
                total_street_contribution,
            } => {
                let increment = total_street_contribution
                    .0
                    .checked_sub(highest)
                    .ok_or(DiagnosticCode::InvalidHand)?;
                if increment <= 0 || stated_raises.get(&action.sequence) != Some(&increment) {
                    return Err(DiagnosticCode::InvalidHand);
                }
                total_street_contribution
                    .0
                    .checked_sub(current)
                    .ok_or(DiagnosticCode::InvalidHand)?
            }
            ActionKind::ReturnUncalled { amount } => -amount.0,
        };
        let total = totals.get_mut(&action.seat).ok_or(malformed)?;
        *total = total
            .checked_add(delta)
            .ok_or(DiagnosticCode::InvalidHand)?;
        if !matches!(action.kind, ActionKind::PostAnte { .. }) {
            let street_total = street_totals.get_mut(&action.seat).ok_or(malformed)?;
            *street_total = street_total
                .checked_add(delta)
                .ok_or(DiagnosticCode::InvalidHand)?;
        }
    }
    let mut levels: Vec<i64> = totals.values().copied().filter(|v| *v > 0).collect();
    levels.sort_unstable();
    levels.dedup();
    let mut lower = 0;
    for upper in levels {
        let contributors: Vec<u8> = totals
            .iter()
            .filter(|(_, v)| **v >= upper)
            .map(|(s, _)| *s)
            .collect();
        let eligible_seats = contributors
            .iter()
            .copied()
            .filter(|s| !folded.contains(s))
            .collect();
        hand.pots.push(Pot {
            amount: Chips(
                upper
                    .checked_sub(lower)
                    .and_then(|v| v.checked_mul(contributors.len() as i64))
                    .ok_or(DiagnosticCode::InvalidHand)?,
            ),
            eligible_seats,
        });
        lower = upper;
    }
    let pot_total = hand
        .pots
        .iter()
        .try_fold(0i64, |sum, pot| sum.checked_add(pot.amount.0))
        .ok_or(DiagnosticCode::InvalidHand)?;
    if declared_total != Some(pot_total) {
        return Err(DiagnosticCode::InvalidHand);
    }
    if !declared_pots.is_empty()
        && (declared_pots.len() != hand.pots.len()
            || declared_pots.iter().zip(&hand.pots).enumerate().any(
                |(index, ((label, amount, _), pot))| {
                    *amount != pot.amount.0
                        || label != if index == 0 { "Main pot" } else { "Side pot" }
                },
            ))
    {
        return Err(DiagnosticCode::InvalidHand);
    }
    for (seat, amount, label) in collected {
        let pot_index = if (label == "pot" && hand.pots.len() == 1) || label == "main pot" {
            0
        } else if label == "side pot" && hand.pots.len() == 2 {
            1
        } else {
            return Err(malformed);
        };
        hand.awards.push(Award {
            pot_index,
            seat,
            amount: Chips(amount),
        });
    }
    let mut actual_awards = BTreeMap::new();
    for award in &hand.awards {
        let total = actual_awards.entry(award.seat).or_insert(0i64);
        *total = total
            .checked_add(award.amount.0)
            .ok_or(DiagnosticCode::InvalidHand)?;
    }
    if actual_awards != summary_awards
        || declared_pots
            .iter()
            .enumerate()
            .any(|(index, (_, _, winner))| {
                !hand
                    .awards
                    .iter()
                    .any(|award| award.pot_index == index && award.seat == *winner)
            })
    {
        return Err(DiagnosticCode::InvalidHand);
    }
    validate_hand(&hand).map_err(|_| DiagnosticCode::InvalidHand)?;
    Ok(hand)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn rejects_invalid_input_before_parsing() {
        assert_eq!(preflight(b" \n"), Err(ImportError::EmptySource));
        assert_eq!(preflight(&[0xff]), Err(ImportError::InvalidEncoding));
        assert_eq!(
            preflight(&vec![b'a'; MAX_SOURCE_BYTES + 1]),
            Err(ImportError::SourceTooLarge)
        );
        assert_eq!(
            parse(b"synthetic history"),
            Err(ImportError::UnsupportedFormat)
        );
    }
    #[test]
    fn golden_side_pot_is_parsed_and_reconciled() {
        let result = parse(include_bytes!(
            "../../../fixtures/hands/golden_side_pot.txt"
        ))
        .unwrap();
        assert!(result.diagnostics.is_empty());
        assert_eq!(result.hands.len(), 1);
        let hand = &result.hands[0];
        assert_eq!(
            hand.pots.iter().map(|p| p.amount.0).collect::<Vec<_>>(),
            vec![300, 200]
        );
        assert_eq!(
            hand.awards.iter().map(|a| a.amount.0).collect::<Vec<_>>(),
            vec![300, 200]
        );
        assert_eq!(validate_hand(hand), Ok(()));
    }
    #[test]
    fn mixed_file_keeps_valid_neighbors_and_reports_bad_span() {
        let source = [
            include_str!("../../../fixtures/hands/normal_fold.txt"),
            include_str!("../../../fixtures/hands/truncated.txt"),
            include_str!("../../../fixtures/hands/golden_side_pot.txt"),
        ]
        .join("\n");
        let result = parse(source.as_bytes()).unwrap();
        assert_eq!(
            result
                .hands
                .iter()
                .map(|h| h.provenance.external_hand_id.as_str())
                .collect::<Vec<_>>(),
            vec!["1002", "1001"]
        );
        assert_eq!(result.hands[0].pots[0].amount.0, 4);
        assert_eq!(result.diagnostics.len(), 1);
        assert_eq!(
            result.diagnostics[0].source_hand_id.as_deref(),
            Some("1003")
        );
        assert_eq!(result.diagnostics[0].code, DiagnosticCode::IncompleteHand);
        assert!(result.diagnostics[0].start_line < result.diagnostics[0].end_line);
    }
    #[test]
    fn rejects_duplicate_id_and_known_card() {
        let golden = include_str!("../../../fixtures/hands/golden_side_pot.txt");
        let duplicate_card = golden
            .replace("Cy: shows [Qs Qh]", "Cy: shows [As Qh]")
            .replace("Hand #1001", "Hand #1004");
        let source = format!("{golden}\n{golden}\n{duplicate_card}");
        let result = parse(source.as_bytes()).unwrap();
        assert_eq!(result.hands.len(), 1);
        assert_eq!(
            result
                .diagnostics
                .iter()
                .map(|d| d.code)
                .collect::<Vec<_>>(),
            vec![DiagnosticCode::DuplicateHandId, DiagnosticCode::InvalidHand]
        );
    }

    #[test]
    fn split_and_raked_pots_reconcile() {
        let source = [
            include_str!("../../../fixtures/hands/split_pot.txt"),
            include_str!("../../../fixtures/hands/raked_pot.txt"),
        ]
        .join("\n");
        let result = parse(source.as_bytes()).unwrap();
        assert!(result.diagnostics.is_empty());
        assert_eq!(result.hands.len(), 2);

        let split = &result.hands[0];
        assert_eq!(split.pots[0].amount.0, 4);
        assert_eq!(split.pots[0].eligible_seats, vec![1, 2]);
        assert_eq!(
            split
                .awards
                .iter()
                .map(|award| (award.seat, award.amount.0))
                .collect::<Vec<_>>(),
            vec![(1, 2), (2, 2)]
        );
        assert_eq!(split.rake.0, 0);

        let raked = &result.hands[1];
        assert_eq!(raked.pots[0].amount.0, 10);
        assert_eq!(raked.awards[0].amount.0, 9);
        assert_eq!(raked.rake.0, 1);
        assert_eq!(validate_hand(raked), Ok(()));
    }

    #[test]
    fn contradictory_board_echo_rejects_only_that_hand() {
        let bad = include_str!("../../../fixtures/hands/golden_side_pot.txt")
            .replace("Hand #1001", "Hand #1007")
            .replace("*** TURN *** [2c 7d 9h]", "*** TURN *** [2c 7d 8h]");
        let source = format!(
            "{}\n{bad}\n{}",
            include_str!("../../../fixtures/hands/normal_fold.txt"),
            include_str!("../../../fixtures/hands/raked_pot.txt")
        );
        let result = parse(source.as_bytes()).unwrap();
        assert_eq!(
            result
                .hands
                .iter()
                .map(|hand| hand.provenance.external_hand_id.as_str())
                .collect::<Vec<_>>(),
            vec!["1002", "1006"]
        );
        assert_eq!(result.diagnostics.len(), 1);
        assert_eq!(
            result.diagnostics[0].source_hand_id.as_deref(),
            Some("1007")
        );
        assert_eq!(result.diagnostics[0].code, DiagnosticCode::InvalidHand);
    }

    #[test]
    fn mucked_cards_remain_unknown() {
        let result = parse(include_bytes!("../../../fixtures/hands/mucked_cards.txt")).unwrap();
        assert!(result.diagnostics.is_empty());
        assert_eq!(result.hands.len(), 1);
        let hand = &result.hands[0];
        assert!(hand.players[0].hole_cards.is_some());
        assert_eq!(hand.players[1].hole_cards, None);
        assert_eq!(hand.awards[0].seat, 1);
    }

    #[test]
    fn conflicting_card_disclosures_are_rejected() {
        let source = include_str!("../../../fixtures/hands/mucked_cards.txt").replace(
            "Bo: mucks hand",
            "Bo: shows [Kc Kd] (a pair)\nBo: mucks hand",
        );
        let result = parse(source.as_bytes()).unwrap();
        assert!(result.hands.is_empty());
        assert_eq!(result.diagnostics.len(), 1);
        assert_eq!(result.diagnostics[0].code, DiagnosticCode::InvalidHand);
    }

    #[test]
    fn duplicate_player_names_are_rejected() {
        let source = include_str!("../../../fixtures/hands/normal_fold.txt")
            .replace("Seat 2: Bo", "Seat 2: Ada");
        let result = parse(source.as_bytes()).unwrap();
        assert!(result.hands.is_empty());
        assert_eq!(result.diagnostics[0].code, DiagnosticCode::InvalidHand);
    }

    #[test]
    fn ante_and_short_all_in_call_reconcile() {
        let source = [
            include_str!("../../../fixtures/hands/ante_fold.txt"),
            include_str!("../../../fixtures/hands/short_all_in_call.txt"),
        ]
        .join("\n");
        let result = parse(source.as_bytes()).unwrap();
        assert!(result.diagnostics.is_empty());
        assert_eq!(result.hands.len(), 2);

        let ante = &result.hands[0];
        assert_eq!(ante.game.ante.0, 1);
        assert_eq!(ante.pots[0].amount.0, 6);
        assert_eq!(ante.awards[0].amount.0, 6);
        assert_eq!(validate_hand(ante), Ok(()));

        let short_call = &result.hands[1];
        assert_eq!(
            short_call
                .pots
                .iter()
                .map(|pot| (pot.amount.0, pot.eligible_seats.clone()))
                .collect::<Vec<_>>(),
            vec![(12, vec![1, 2, 3]), (12, vec![2, 3])]
        );
        assert_eq!(
            short_call
                .awards
                .iter()
                .map(|award| (award.pot_index, award.seat, award.amount.0))
                .collect::<Vec<_>>(),
            vec![(0, 1, 12), (1, 2, 12)]
        );
        assert_eq!(validate_hand(short_call), Ok(()));
    }

    #[test]
    fn inconsistent_ante_and_wrong_payout_reject_only_their_spans() {
        let bad_ante = include_str!("../../../fixtures/hands/ante_fold.txt")
            .replace("Hand #1009", "Hand #1011")
            .replace("Bo: posts the ante $0.01", "Bo: posts the ante $0.02");
        let bad_payout = include_str!("../../../fixtures/hands/short_all_in_call.txt")
            .replace("Hand #1010", "Hand #1012")
            .replace(
                "Bo collected $0.12 from side pot",
                "Cy collected $0.12 from side pot",
            );
        let source = format!(
            "{}\n{bad_ante}\n{bad_payout}\n{}",
            include_str!("../../../fixtures/hands/ante_fold.txt"),
            include_str!("../../../fixtures/hands/short_all_in_call.txt")
        );
        let result = parse(source.as_bytes()).unwrap();
        assert_eq!(
            result
                .hands
                .iter()
                .map(|hand| hand.provenance.external_hand_id.as_str())
                .collect::<Vec<_>>(),
            vec!["1009", "1010"]
        );
        assert_eq!(
            result
                .diagnostics
                .iter()
                .map(|diagnostic| (diagnostic.source_hand_id.as_deref(), diagnostic.code))
                .collect::<Vec<_>>(),
            vec![
                (Some("1011"), DiagnosticCode::InvalidHand),
                (Some("1012"), DiagnosticCode::InvalidHand)
            ]
        );
    }

    #[test]
    fn missing_or_repeated_ante_is_rejected() {
        let fixture = include_str!("../../../fixtures/hands/ante_fold.txt");
        for source in [
            fixture.replace("Bo: posts the ante $0.01\n", ""),
            fixture.replace(
                "Bo: posts the ante $0.01",
                "Bo: posts the ante $0.01\nBo: posts the ante $0.01",
            ),
        ] {
            let result = parse(source.as_bytes()).unwrap();
            assert!(result.hands.is_empty());
            assert_eq!(result.diagnostics[0].code, DiagnosticCode::InvalidHand);
        }
    }

    #[test]
    fn accepts_blank_and_indented_action_lines_but_enforces_source_limits() {
        let source = include_str!("../../../fixtures/hands/normal_fold.txt")
            .replace("Ada: calls $0.01", "  Ada: calls $0.01  \n\n");
        let result = parse(source.as_bytes()).unwrap();
        assert_eq!(result.hands.len(), 1);
        assert!(result.diagnostics.is_empty());

        let overlong = format!(
            "{}\n{}",
            include_str!("../../../fixtures/hands/normal_fold.txt"),
            "x".repeat(MAX_LINE_BYTES + 1)
        );
        assert_eq!(parse(overlong.as_bytes()), Err(ImportError::SourceLimit));

        let headers =
            "PokerStars Hand #1: Hold'em No Limit ($0.01/$0.02 USD) - 2026/10/23 12:00:00 UTC\n"
                .repeat(MAX_HANDS + 1);
        assert_eq!(parse(headers.as_bytes()), Err(ImportError::SourceLimit));
    }

    #[test]
    fn contradictory_or_missing_structure_rejects_only_its_hand() {
        let source = [
            include_str!("../../../fixtures/hands/normal_fold.txt"),
            include_str!("../../../fixtures/hands/missing_hole_marker.txt"),
            include_str!("../../../fixtures/hands/wrong_small_blind.txt"),
            include_str!("../../../fixtures/hands/missing_big_blind.txt"),
            include_str!("../../../fixtures/hands/raked_pot.txt"),
        ]
        .join("\n");
        let result = parse(source.as_bytes()).unwrap();
        assert_eq!(
            result
                .hands
                .iter()
                .map(|hand| hand.provenance.external_hand_id.as_str())
                .collect::<Vec<_>>(),
            vec!["1002", "1006"]
        );
        assert_eq!(
            result
                .diagnostics
                .iter()
                .map(|diagnostic| (diagnostic.source_hand_id.as_deref(), diagnostic.code))
                .collect::<Vec<_>>(),
            vec![
                (Some("1013"), DiagnosticCode::InvalidHand),
                (Some("1014"), DiagnosticCode::InvalidHand),
                (Some("1015"), DiagnosticCode::InvalidHand),
            ]
        );
    }

    #[test]
    fn repeated_marker_or_blind_and_late_ante_are_rejected() {
        let fixture = include_str!("../../../fixtures/hands/normal_fold.txt");
        let cases = [
            fixture.replace(
                "*** HOLE CARDS ***",
                "*** HOLE CARDS ***\n*** HOLE CARDS ***",
            ),
            fixture.replace(
                "Bo: posts big blind $0.02",
                "Bo: posts big blind $0.02\nBo: posts big blind $0.02",
            ),
            fixture.replace(
                "Ada: calls $0.01",
                "Ada: posts the ante $0.01\nAda: calls $0.01",
            ),
        ];
        for source in cases {
            let result = parse(source.as_bytes()).unwrap();
            assert!(result.hands.is_empty());
            assert_eq!(result.diagnostics[0].code, DiagnosticCode::InvalidHand);
        }
    }

    #[test]
    fn contradictory_raise_increment_rejects_only_its_hand() {
        let source = [
            include_str!("../../../fixtures/hands/normal_fold.txt"),
            include_str!("../../../fixtures/hands/wrong_raise_increment.txt"),
            include_str!("../../../fixtures/hands/short_all_in_call.txt"),
        ]
        .join("\n");
        let result = parse(source.as_bytes()).unwrap();
        assert_eq!(
            result
                .hands
                .iter()
                .map(|hand| hand.provenance.external_hand_id.as_str())
                .collect::<Vec<_>>(),
            vec!["1002", "1010"]
        );
        assert_eq!(result.diagnostics.len(), 1);
        assert_eq!(
            result.diagnostics[0].source_hand_id.as_deref(),
            Some("1016")
        );
        assert_eq!(result.diagnostics[0].code, DiagnosticCode::InvalidHand);
    }

    #[test]
    fn impossible_betting_actions_reject_only_their_hands() {
        let source = [
            include_str!("../../../fixtures/hands/normal_fold.txt"),
            include_str!("../../../fixtures/hands/check_facing_bet.txt"),
            include_str!("../../../fixtures/hands/short_call_not_all_in.txt"),
            include_str!("../../../fixtures/hands/bet_facing_bet.txt"),
            include_str!("../../../fixtures/hands/raked_pot.txt"),
        ]
        .join("\n");
        let result = parse(source.as_bytes()).unwrap();
        assert_eq!(
            result
                .hands
                .iter()
                .map(|hand| hand.provenance.external_hand_id.as_str())
                .collect::<Vec<_>>(),
            vec!["1002", "1006"]
        );
        assert_eq!(
            result
                .diagnostics
                .iter()
                .map(|diagnostic| (diagnostic.source_hand_id.as_deref(), diagnostic.code))
                .collect::<Vec<_>>(),
            vec![
                (Some("1017"), DiagnosticCode::InvalidHand),
                (Some("1018"), DiagnosticCode::InvalidHand),
                (Some("1019"), DiagnosticCode::InvalidHand),
            ]
        );
    }

    #[test]
    fn adversarial_fixture_diagnostics_preserve_valid_neighbors() {
        let bad = [
            (
                include_str!("../../../fixtures/hands/same_seat_blinds.txt"),
                "1020",
                DiagnosticCode::InvalidHand,
            ),
            (
                include_str!("../../../fixtures/hands/missing_summary.txt"),
                "1021",
                DiagnosticCode::IncompleteHand,
            ),
            (
                include_str!("../../../fixtures/hands/wrong_uncalled_return.txt"),
                "1022",
                DiagnosticCode::InvalidHand,
            ),
            (
                include_str!("../../../fixtures/hands/duplicate_board_card.txt"),
                "1023",
                DiagnosticCode::InvalidHand,
            ),
            (
                include_str!("../../../fixtures/hands/unsupported_currency.txt"),
                "1024",
                DiagnosticCode::UnsupportedFormat,
            ),
        ];
        let mut source = include_str!("../../../fixtures/hands/normal_fold.txt").to_owned();
        let mut expected = Vec::new();
        for (fixture, id, code) in bad {
            source.push('\n');
            source.push_str(fixture);
            expected.push((id, code));
        }
        source.push('\n');
        source.push_str(include_str!("../../../fixtures/hands/raked_pot.txt"));
        let header_lines: Vec<_> = source
            .lines()
            .enumerate()
            .filter_map(|(index, line)| line.starts_with("PokerStars Hand #").then_some(index + 1))
            .collect();

        let result = parse(source.as_bytes()).unwrap();
        assert_eq!(
            result
                .hands
                .iter()
                .map(|hand| hand.provenance.external_hand_id.as_str())
                .collect::<Vec<_>>(),
            vec!["1002", "1006"]
        );
        assert_eq!(result.diagnostics.len(), expected.len());
        for (index, (diagnostic, (id, code))) in result.diagnostics.iter().zip(expected).enumerate()
        {
            assert_eq!(diagnostic.source_hand_id.as_deref(), Some(id));
            assert_eq!(diagnostic.code, code, "hand {id}");
            assert_eq!(diagnostic.start_line, header_lines[index + 1]);
            assert_eq!(diagnostic.end_line, header_lines[index + 2] - 1);
            assert_eq!(diagnostic.parser_version, PARSER_VERSION);
        }
    }
}
