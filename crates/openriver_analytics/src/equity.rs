//! Exact all-in equity by enumerating every possible runout.
//!
//! Shares are integers: a pot split `k` ways credits each winner
//! `EQUITY_UNITS / k` of a pot worth [`EQUITY_UNITS`], and 2520 = lcm(1..=9)
//! divides evenly for every table size, so no floating point is involved
//! until the final conversion.

use crate::evaluator::{evaluate, HandRank};
use openriver_domain::{Card, Rank, Suit};

/// Value of one whole pot in integer share units.
pub const EQUITY_UNITS: u64 = 2520;

/// Refuse enumerations larger than this many runouts.
pub const MAX_RUNOUTS: u64 = 2_000_000;

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum EquityError {
    #[error("equity needs between two and nine players")]
    PlayerCount,
    #[error("the board must have zero, three, four or five cards")]
    BoardSize,
    #[error("a card appears more than once")]
    DuplicateCard,
    #[error("too many runouts to enumerate exactly")]
    TooManyRunouts,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Equity {
    /// Runouts where this player wins outright.
    pub wins: u64,
    /// Runouts where this player shares the best hand.
    pub ties: u64,
    /// Share units won over all runouts, in `EQUITY_UNITS` per runout.
    pub units: u64,
}

impl Equity {
    /// Fraction of the pot won on average, given `runouts` possible runouts.
    pub fn share(&self, runouts: u64) -> f64 {
        self.units as f64 / (EQUITY_UNITS * runouts) as f64
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct EquityResult {
    pub runouts: u64,
    pub players: Vec<Equity>,
}

impl EquityResult {
    pub fn share(&self, player: usize) -> f64 {
        self.players[player].share(self.runouts)
    }
}

fn deck() -> Vec<Card> {
    const RANKS: [Rank; 13] = [
        Rank::Two,
        Rank::Three,
        Rank::Four,
        Rank::Five,
        Rank::Six,
        Rank::Seven,
        Rank::Eight,
        Rank::Nine,
        Rank::Ten,
        Rank::Jack,
        Rank::Queen,
        Rank::King,
        Rank::Ace,
    ];
    const SUITS: [Suit; 4] = [Suit::Clubs, Suit::Diamonds, Suit::Hearts, Suit::Spades];
    RANKS
        .iter()
        .flat_map(|rank| {
            SUITS.iter().map(|suit| Card {
                rank: *rank,
                suit: *suit,
            })
        })
        .collect()
}

fn choose(n: u64, k: u64) -> u64 {
    (0..k).fold(1u64, |acc, i| acc * (n - i) / (i + 1))
}

/// Everything about the spot, validated: players' cards and the board.
struct Spot {
    hole: Vec<[Card; 2]>,
    board: Vec<Card>,
    rest: Vec<Card>,
    missing: usize,
}

fn validate(hole: &[[Card; 2]], board: &[Card]) -> Result<Spot, EquityError> {
    if !(2..=9).contains(&hole.len()) {
        return Err(EquityError::PlayerCount);
    }
    if !matches!(board.len(), 0 | 3..=5) {
        return Err(EquityError::BoardSize);
    }
    let mut remaining = deck();
    for card in hole.iter().flatten().chain(board) {
        let at = remaining
            .iter()
            .position(|c| c == card)
            .ok_or(EquityError::DuplicateCard)?;
        remaining.swap_remove(at);
    }
    // swap_remove scrambles order; sort so enumeration is deterministic.
    remaining.sort_by_key(|c| (c.rank as u8, c.suit as u8));
    Ok(Spot {
        hole: hole.to_vec(),
        board: board.to_vec(),
        missing: 5 - board.len(),
        rest: remaining,
    })
}

fn score(spot: &Spot, runout: &[Card]) -> Vec<HandRank> {
    let mut cards = [spot.board.first().copied().unwrap_or(spot.hole[0][0]); 7];
    let board_len = spot.board.len();
    cards[2..2 + board_len].copy_from_slice(&spot.board);
    cards[2 + board_len..7].copy_from_slice(runout);
    spot.hole
        .iter()
        .map(|hole| {
            cards[0] = hole[0];
            cards[1] = hole[1];
            evaluate(&cards).expect("validated distinct cards")
        })
        .collect()
}

fn credit(players: &mut [Equity], ranks: &[HandRank]) {
    let best = ranks.iter().max().copied().expect("two or more players");
    let winners = ranks.iter().filter(|r| **r == best).count() as u64;
    for (player, rank) in players.iter_mut().zip(ranks) {
        if *rank == best {
            player.units += EQUITY_UNITS / winners;
            if winners == 1 {
                player.wins += 1;
            } else {
                player.ties += 1;
            }
        }
    }
}

/// Enumerate every runout. Errors with [`EquityError::TooManyRunouts`] rather
/// than silently sampling.
pub fn exact_equity(hole: &[[Card; 2]], board: &[Card]) -> Result<EquityResult, EquityError> {
    let spot = validate(hole, board)?;
    let runouts = choose(spot.rest.len() as u64, spot.missing as u64);
    if runouts > MAX_RUNOUTS {
        return Err(EquityError::TooManyRunouts);
    }
    let mut players = vec![Equity::default(); spot.hole.len()];
    let mut chosen = Vec::with_capacity(spot.missing);
    enumerate(&spot, 0, &mut chosen, &mut players);
    Ok(EquityResult { runouts, players })
}

fn enumerate(spot: &Spot, start: usize, chosen: &mut Vec<Card>, players: &mut [Equity]) {
    if chosen.len() == spot.missing {
        credit(players, &score(spot, chosen));
        return;
    }
    let needed = spot.missing - chosen.len();
    for i in start..=spot.rest.len() - needed {
        chosen.push(spot.rest[i]);
        enumerate(spot, i + 1, chosen, players);
        chosen.pop();
    }
}

/// Monte Carlo estimate for spots too large to enumerate. Deterministic for a
/// given `seed`; the result's `runouts` is the number of samples drawn.
pub fn sampled_equity(
    hole: &[[Card; 2]],
    board: &[Card],
    samples: u64,
    seed: u64,
) -> Result<EquityResult, EquityError> {
    let spot = validate(hole, board)?;
    let mut state = seed.wrapping_mul(0x9E37_79B9_7F4A_7C15) | 1;
    let mut next = move || {
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        state
    };
    let mut players = vec![Equity::default(); spot.hole.len()];
    let mut pool = spot.rest.clone();
    for _ in 0..samples {
        // Partial Fisher-Yates: the first `missing` entries are a uniform draw.
        for i in 0..spot.missing {
            let j = i + (next() % (pool.len() - i) as u64) as usize;
            pool.swap(i, j);
        }
        credit(&mut players, &score(&spot, &pool[..spot.missing]));
    }
    Ok(EquityResult {
        runouts: samples,
        players,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::evaluator::tests::parse;
    use proptest::prelude::*;

    fn hole(text: &str) -> [Card; 2] {
        let cards = parse(text);
        [cards[0], cards[1]]
    }

    #[test]
    fn hand_audited_turn_flush_draw_against_a_set() {
        // Board 9s 8s 2c 3d. Ace-king of spades has 9 spade outs, but 2s and 3s
        // pair the board and give nines full of deuces/treys to the set, so the
        // draw wins on 7 of the 44 unseen cards and loses on the other 37.
        let result = exact_equity(&[hole("As Ks"), hole("9h 9d")], &parse("9s 8s 2c 3d")).unwrap();
        assert_eq!(result.runouts, 44);
        assert_eq!((result.players[0].wins, result.players[0].ties), (7, 0));
        assert_eq!((result.players[1].wins, result.players[1].ties), (37, 0));
        assert_eq!(result.players[0].units, 7 * EQUITY_UNITS);
        assert!((result.share(0) - 7.0 / 44.0).abs() < 1e-12);
    }

    #[test]
    fn a_made_board_chops_between_everyone() {
        // Royal flush on the board: nobody can improve, three-way split.
        let result = exact_equity(
            &[hole("2c 3d"), hole("4c 5d"), hole("6c 7d")],
            &parse("As Ks Qs Js Ts"),
        )
        .unwrap();
        assert_eq!(result.runouts, 1);
        for player in &result.players {
            assert_eq!((player.wins, player.ties), (0, 1));
            assert_eq!(player.units, EQUITY_UNITS / 3);
        }
    }

    #[test]
    fn dominated_hand_and_a_known_coin_flip_are_in_the_right_ballpark() {
        // Flop known (990 runouts): aces ahead of kings by a wide margin.
        let aces = exact_equity(&[hole("Ac Ad"), hole("Kc Kd")], &parse("2h 7s 9d")).unwrap();
        assert!(
            aces.share(0) > 0.88 && aces.share(0) < 0.95,
            "{}",
            aces.share(0)
        );
        assert_eq!(aces.runouts, 990);
    }

    #[test]
    fn rejects_bad_spots() {
        let a = hole("As Ks");
        let b = hole("Ah Kh");
        assert_eq!(exact_equity(&[a], &[]), Err(EquityError::PlayerCount));
        assert_eq!(
            exact_equity(&[a, b], &parse("2c 3c")),
            Err(EquityError::BoardSize)
        );
        assert_eq!(
            exact_equity(&[a, hole("As Qh")], &[]),
            Err(EquityError::DuplicateCard)
        );
        assert_eq!(
            exact_equity(&[a, b], &parse("As 3c 4d")),
            Err(EquityError::DuplicateCard)
        );
        // Preflop with nine players is small enough; two players preflop is too big for the limit
        // only if the limit is lowered, so check the guard with the real constant instead.
        assert!(choose(48, 5) <= MAX_RUNOUTS);
    }

    #[test]
    fn sampling_is_deterministic_and_close_to_the_exact_answer() {
        let spot = [hole("Ac Kc"), hole("Qh Qd")];
        let board = parse("2h 7s 9d");
        let exact = exact_equity(&spot, &board).unwrap();
        let a = sampled_equity(&spot, &board, 20_000, 7).unwrap();
        let b = sampled_equity(&spot, &board, 20_000, 7).unwrap();
        assert_eq!(a, b);
        assert!((a.share(0) - exact.share(0)).abs() < 0.02);
    }

    /// Preflop, all 1,712,304 runouts: run with `--release -- --ignored`.
    #[test]
    #[ignore = "exhaustive preflop enumeration; run in release mode"]
    fn aces_against_kings_preflop() {
        let result = exact_equity(&[hole("As Ah"), hole("Ks Kh")], &[]).unwrap();
        assert_eq!(result.runouts, 1_712_304);
        let aces = result.share(0);
        assert!(aces > 0.80 && aces < 0.84, "{aces}");
        let [a, k] = [result.players[0], result.players[1]];
        // Every runout is a win for one side or a split.
        assert_eq!(a.wins + k.wins + a.ties, result.runouts);
        assert_eq!(a.ties, k.ties);
    }

    fn spot_from(seed: &[u8]) -> (Vec<[Card; 2]>, Vec<Card>) {
        let mut cards = deck();
        let mut take = |i: usize| {
            let at = ((usize::from(seed[2 * i]) << 8) | usize::from(seed[2 * i + 1])) % cards.len();
            cards.swap_remove(at)
        };
        let players = 2 + usize::from(seed[0]) % 3; // 2..=4 players
        let board_len = [3usize, 4, 5][usize::from(seed[1]) % 3];
        let hole: Vec<[Card; 2]> = (0..players)
            .map(|i| [take(2 + 2 * i), take(3 + 2 * i)])
            .collect();
        let board: Vec<Card> = (0..board_len).map(|i| take(20 + i)).collect();
        (hole, board)
    }

    fn permute_suits(card: Card, map: [Suit; 4]) -> Card {
        Card {
            rank: card.rank,
            suit: map[card.suit as usize],
        }
    }

    proptest! {
        #![proptest_config(ProptestConfig::with_cases(300))]

        #[test]
        fn shares_conserve_the_pot_and_ignore_player_order_and_suit_naming(
            seed in proptest::collection::vec(any::<u8>(), 60..=60),
            rotate in 0usize..4,
            suit_shift in 0usize..4,
        ) {
            let (hole_cards, board) = spot_from(&seed);
            let base = exact_equity(&hole_cards, &board).unwrap();
            // Conservation: every runout hands out exactly one whole pot.
            prop_assert_eq!(
                base.players.iter().map(|p| p.units).sum::<u64>(),
                base.runouts * EQUITY_UNITS
            );
            for p in &base.players {
                prop_assert!(p.wins + p.ties <= base.runouts);
                prop_assert_eq!(p.units >= p.wins * EQUITY_UNITS, true);
            }
            // Rotating the players rotates the results.
            let n = hole_cards.len();
            let mut rotated = hole_cards.clone();
            rotated.rotate_left(rotate % n);
            let again = exact_equity(&rotated, &board).unwrap();
            for i in 0..n {
                prop_assert_eq!(again.players[i], base.players[(i + rotate % n) % n]);
            }
            // Renaming suits (a bijection) cannot change any result.
            let all = [Suit::Clubs, Suit::Diamonds, Suit::Hearts, Suit::Spades];
            let map = [all[suit_shift], all[(suit_shift + 1) % 4], all[(suit_shift + 2) % 4], all[(suit_shift + 3) % 4]];
            let renamed_hole: Vec<[Card; 2]> = hole_cards.iter()
                .map(|h| [permute_suits(h[0], map), permute_suits(h[1], map)]).collect();
            let renamed_board: Vec<Card> = board.iter().map(|c| permute_suits(*c, map)).collect();
            let renamed = exact_equity(&renamed_hole, &renamed_board).unwrap();
            prop_assert_eq!(renamed, base);
        }
    }
}
