//! Texas hold'em hand evaluation: the best five of five to seven cards.
//!
//! A [`HandRank`] is a single comparable value: higher beats lower, equal
//! ranks split. Suits never break ties.

use openriver_domain::{Card, Rank, Suit};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum Category {
    HighCard,
    Pair,
    TwoPair,
    ThreeOfAKind,
    Straight,
    Flush,
    FullHouse,
    FourOfAKind,
    StraightFlush,
}

/// Category in the high bits, then up to five tie-break ranks (4 bits each,
/// most significant first). Comparing the integers compares hands.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct HandRank(u32);

impl HandRank {
    pub fn category(self) -> Category {
        match self.0 >> 20 {
            0 => Category::HighCard,
            1 => Category::Pair,
            2 => Category::TwoPair,
            3 => Category::ThreeOfAKind,
            4 => Category::Straight,
            5 => Category::Flush,
            6 => Category::FullHouse,
            7 => Category::FourOfAKind,
            _ => Category::StraightFlush,
        }
    }

    fn new(category: Category, tiebreak: &[u8]) -> Self {
        debug_assert!(tiebreak.len() <= 5);
        let mut value = (category as u32) << 20;
        for (i, rank) in tiebreak.iter().enumerate() {
            value |= u32::from(*rank) << (16 - 4 * i);
        }
        Self(value)
    }
}

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum EvaluationError {
    #[error("a hand needs between five and seven cards")]
    CardCount,
    #[error("a card appears more than once")]
    DuplicateCard,
}

fn rank_index(rank: Rank) -> u8 {
    rank as u8
}

fn suit_index(suit: Suit) -> usize {
    suit as usize
}

/// Highest card of the best straight in a 13-bit rank mask (bit 0 = two),
/// counting the ace as low for the wheel. Returns the high-card rank index.
fn straight_high(mask: u16) -> Option<u8> {
    // Ace also plays low: a copy of the ace bit below the deuce.
    let extended = (u32::from(mask) << 1) | u32::from(mask >> 12 & 1);
    (0..=9u8)
        .rev()
        .find(|&low| {
            let window = 0b11111u32 << low;
            extended & window == window
        })
        // `low` indexes the extended mask whose bit 0 is the low ace, so the top
        // card of the window is rank index `low + 3` (wheel: low 0 -> five = 3).
        .map(|low| low + 3)
}

fn top_ranks(mask: u16, count: usize) -> Vec<u8> {
    (0..13u8)
        .rev()
        .filter(|rank| mask >> rank & 1 == 1)
        .take(count)
        .collect()
}

pub fn evaluate(cards: &[Card]) -> Result<HandRank, EvaluationError> {
    if !(5..=7).contains(&cards.len()) {
        return Err(EvaluationError::CardCount);
    }
    let mut counts = [0u8; 13];
    let mut suit_masks = [0u16; 4];
    let mut seen = 0u64;
    for card in cards {
        let rank = rank_index(card.rank);
        let suit = suit_index(card.suit);
        let bit = 1u64 << (suit * 13 + rank as usize);
        if seen & bit != 0 {
            return Err(EvaluationError::DuplicateCard);
        }
        seen |= bit;
        counts[rank as usize] += 1;
        suit_masks[suit] |= 1 << rank;
    }
    let rank_mask = suit_masks.iter().fold(0u16, |all, m| all | m);

    if let Some(flush_mask) = suit_masks
        .iter()
        .copied()
        .find(|mask| mask.count_ones() >= 5)
    {
        if let Some(high) = straight_high(flush_mask) {
            return Ok(HandRank::new(Category::StraightFlush, &[high]));
        }
        return Ok(HandRank::new(Category::Flush, &top_ranks(flush_mask, 5)));
    }

    let by_count = |n: u8| -> Vec<u8> {
        (0..13u8)
            .rev()
            .filter(|rank| counts[*rank as usize] == n)
            .collect()
    };
    let quads = by_count(4);
    let trips = by_count(3);
    let pairs = by_count(2);
    let singles = by_count(1);

    if let Some(&quad) = quads.first() {
        // Kicker: the best remaining card of any other count.
        let kicker = (0..13u8)
            .rev()
            .find(|rank| *rank != quad && counts[*rank as usize] > 0)
            .expect("five cards or more");
        return Ok(HandRank::new(Category::FourOfAKind, &[quad, kicker]));
    }
    if let Some(&trip) = trips.first() {
        // A second set of trips can serve as the pair of a full house.
        let pair = trips.iter().skip(1).chain(pairs.iter()).copied().max();
        if let Some(pair) = pair {
            return Ok(HandRank::new(Category::FullHouse, &[trip, pair]));
        }
    }
    if let Some(high) = straight_high(rank_mask) {
        return Ok(HandRank::new(Category::Straight, &[high]));
    }
    if let Some(&trip) = trips.first() {
        let kickers: Vec<u8> = singles.iter().copied().take(2).collect();
        let mut tiebreak = vec![trip];
        tiebreak.extend(kickers);
        return Ok(HandRank::new(Category::ThreeOfAKind, &tiebreak));
    }
    if pairs.len() >= 2 {
        // With three pairs the third pair's rank may still be the best kicker.
        let kicker = pairs
            .iter()
            .skip(2)
            .chain(singles.iter())
            .copied()
            .max()
            .expect("seven cards leave a kicker");
        let kicker = if cards.len() == 5 {
            *singles.first().expect("five cards leave a kicker")
        } else {
            kicker
        };
        return Ok(HandRank::new(
            Category::TwoPair,
            &[pairs[0], pairs[1], kicker],
        ));
    }
    if let Some(&pair) = pairs.first() {
        let mut tiebreak = vec![pair];
        tiebreak.extend(singles.iter().copied().take(3));
        return Ok(HandRank::new(Category::Pair, &tiebreak));
    }
    Ok(HandRank::new(
        Category::HighCard,
        &singles.iter().copied().take(5).collect::<Vec<_>>(),
    ))
}

#[cfg(test)]
pub(crate) mod tests {
    use super::*;

    pub fn parse(text: &str) -> Vec<Card> {
        text.split_whitespace()
            .map(|token| {
                let mut chars = token.chars();
                let rank = match chars.next().unwrap() {
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
                    other => panic!("bad rank {other}"),
                };
                let suit = match chars.next().unwrap() {
                    'c' => Suit::Clubs,
                    'd' => Suit::Diamonds,
                    'h' => Suit::Hearts,
                    's' => Suit::Spades,
                    other => panic!("bad suit {other}"),
                };
                Card { rank, suit }
            })
            .collect()
    }

    fn rank(text: &str) -> HandRank {
        evaluate(&parse(text)).unwrap()
    }

    #[test]
    fn categories_are_recognised() {
        use Category::*;
        for (cards, expected) in [
            ("As Ks Qs Js Ts", StraightFlush),
            ("5h 4h 3h 2h Ah", StraightFlush), // steel wheel
            ("9c 9d 9h 9s 2c", FourOfAKind),
            ("9c 9d 9h 2s 2c", FullHouse),
            ("As 2s 9s Js 4s", Flush),
            ("Tc 9d 8h 7s 6c", Straight),
            ("Ac 2d 3h 4s 5c", Straight), // wheel
            ("Ac Kd Qh Js Tc", Straight), // broadway
            ("9c 9d 9h 2s 3c", ThreeOfAKind),
            ("9c 9d 2h 2s 3c", TwoPair),
            ("9c 9d 2h 5s 3c", Pair),
            ("Ac Kd Qh Js 9c", HighCard),
        ] {
            assert_eq!(rank(cards).category(), expected, "{cards}");
        }
    }

    #[test]
    fn ordering_within_and_across_categories() {
        let ascending = [
            "7c 5d 4h 3s 2c", // seven high
            "Ac Kd Qh Js 9c", // ace high
            "2c 2d 5h 4s 3c", // pair of deuces
            "Ac Ad 5h 4s 3c", // pair of aces
            "Ac Ad 5h 5s 3c", // aces and fives, trey kicker
            "Ac Ad 5h 5s 4c", // aces and fives, four kicker
            "Ac Ad Kh Ks 2c", // aces and kings
            "2c 2d 2h 5s 3c", // trip deuces
            "Ac Ad Ah 5s 3c", // trip aces
            "Ac 2d 3h 4s 5c", // wheel
            "2c 3d 4h 5s 6c", // six high
            "Tc Jd Qh Ks Ac", // broadway
            "2s 3s 4s 5s 7s", // seven-high flush
            "As Ks Qs Js 9s", // ace-high flush
            "2c 2d 2h 3s 3c", // deuces full of treys
            "3c 3d 3h 2s 2c", // treys full of deuces
            "2c 2d 2h 2s 3c", // quad deuces
            "Ac Ad Ah As Kc", // quad aces
            "5h 4h 3h 2h Ah", // steel wheel
            "As Ks Qs Js Ts", // royal flush
        ];
        let ranks: Vec<_> = ascending.iter().map(|c| rank(c)).collect();
        assert!(ranks.windows(2).all(|w| w[0] < w[1]), "{ranks:?}");
    }

    #[test]
    fn suits_never_break_ties() {
        assert_eq!(rank("As Kd Qh Js 9c"), rank("Ac Kh Qd Jc 9s"));
        assert_eq!(rank("2c 2d 5h 4s 3c"), rank("2h 2s 5c 4d 3h"));
    }

    #[test]
    fn seven_cards_pick_the_best_five() {
        // Two trips: the lower trips plays as the pair.
        assert_eq!(rank("Ac Ad Ah Kc Kd Kh 2s"), rank("Ac Ad Ah Kc Kd 2s 3s"));
        // Three pairs: the best two play, the best remaining card kicks.
        assert_eq!(rank("Ac Ad Kc Kd 5c 5d 6s"), rank("Ac Ad Kc Kd 6s 2h 3h"));
        assert!(rank("Ac Ad Kc Kd 6c 5d 5s") > rank("Ac Ad Kc Kd 4c 3d 2s"));
        // A flush beats the straight also present; a straight flush beats the flush.
        assert_eq!(rank("9s 8s 7s 6s 2s 5d 4h").category(), Category::Flush);
        assert_eq!(
            rank("9s 8s 7s 6s 5s 4d 3h").category(),
            Category::StraightFlush
        );
        // Straight flush requires the straight within one suit.
        assert_eq!(rank("9s 8s 7s 6s 2s 5d 4s").category(), Category::Flush);
        // Wheel inside seven cards, with a higher card present.
        assert_eq!(rank("Ac 2d 3h 4s 5c Kd Qh").category(), Category::Straight);
        assert_eq!(rank("Ac 2d 3h 4s 5c 6d Kh"), rank("2c 3d 4h 5s 6c 8d 9h"));
        // Six-high straight outranks the wheel.
        assert!(rank("Ac 2d 3h 4s 5c 6d Kh") > rank("Ac 2d 3h 4s 5c Kd Qh"));
        // Quads with a pair and a trip also present: kicker is the best other card.
        assert_eq!(rank("9c 9d 9h 9s Ah Ad Ac"), rank("9c 9d 9h 9s Ah 2d 3c"));
    }

    #[test]
    fn rejects_bad_input() {
        assert_eq!(
            evaluate(&parse("As Ks Qs Js")),
            Err(EvaluationError::CardCount)
        );
        assert_eq!(
            evaluate(&parse("As Ks Qs Js Ts 9s 8s 7s")),
            Err(EvaluationError::CardCount)
        );
        assert_eq!(
            evaluate(&parse("As As Qs Js Ts")),
            Err(EvaluationError::DuplicateCard)
        );
    }

    /// Deliberately different from `evaluate`: group ranks by (count, rank),
    /// then classify the shape. Returns a lexicographically comparable score.
    fn naive_score(cards: &[Card]) -> Vec<u8> {
        assert_eq!(cards.len(), 5);
        let mut ranks: Vec<u8> = cards.iter().map(|c| c.rank as u8).collect();
        ranks.sort_unstable_by(|a, b| b.cmp(a));
        let flush = cards.iter().all(|c| c.suit == cards[0].suit);
        let mut unique = ranks.clone();
        unique.dedup();
        let straight_top = if unique.len() == 5 && unique[0] - unique[4] == 4 {
            Some(unique[0])
        } else if unique == vec![12, 3, 2, 1, 0] {
            Some(3) // wheel plays as five-high
        } else {
            None
        };
        let mut groups: Vec<(u8, u8)> = unique
            .iter()
            .map(|r| (ranks.iter().filter(|x| *x == r).count() as u8, *r))
            .collect();
        groups.sort_unstable_by(|a, b| b.cmp(a));
        let shape: Vec<u8> = groups.iter().map(|g| g.0).collect();
        let category = match (flush, straight_top, shape.as_slice()) {
            (true, Some(_), _) => 8,
            (_, _, [4, 1]) => 7,
            (_, _, [3, 2]) => 6,
            (true, None, _) => 5,
            (false, Some(_), _) => 4,
            (_, _, [3, 1, 1]) => 3,
            (_, _, [2, 2, 1]) => 2,
            (_, _, [2, 1, 1, 1]) => 1,
            _ => 0,
        };
        let mut score = vec![category];
        match straight_top {
            Some(top) if category == 8 || category == 4 => score.push(top),
            _ => score.extend(groups.iter().map(|g| g.1)),
        }
        score
    }

    /// The evaluator must order all 2,598,960 five-card hands exactly as the
    /// naive scorer does: equal where it is equal, strictly higher where higher.
    #[test]
    fn evaluator_order_agrees_with_the_naive_scorer_on_every_five_card_hand() {
        let deck = full_deck();
        // Pad to six nibbles (category + five tie-breaks) so lengths align.
        let pack = |mut score: Vec<u8>| {
            score.resize(6, 0);
            score.iter().fold(0u64, |acc, b| (acc << 4) | u64::from(*b))
        };
        let mut all: Vec<(u64, HandRank)> = Vec::with_capacity(2_598_960);
        let n = deck.len();
        for a in 0..n {
            for b in a + 1..n {
                for c in b + 1..n {
                    for d in c + 1..n {
                        for e in d + 1..n {
                            let hand = [deck[a], deck[b], deck[c], deck[d], deck[e]];
                            all.push((pack(naive_score(&hand)), evaluate(&hand).unwrap()));
                        }
                    }
                }
            }
        }
        assert_eq!(all.len(), 2_598_960);
        all.sort_unstable();
        for pair in all.windows(2) {
            let ((s0, r0), (s1, r1)) = (pair[0], pair[1]);
            if s0 == s1 {
                assert_eq!(r0, r1, "equal naive scores must tie");
            } else {
                assert!(r0 < r1, "naive {s0:x} < {s1:x} but ranks {r0:?} !< {r1:?}");
            }
        }
        // Exactly 7,462 distinct hand values exist in five-card poker.
        let mut distinct: Vec<HandRank> = all.iter().map(|(_, r)| *r).collect();
        distinct.dedup();
        assert_eq!(distinct.len(), 7_462);
    }

    fn distinct_cards(seed: &[u8], n: usize) -> Vec<Card> {
        let mut deck = full_deck();
        let mut picks = Vec::new();
        let mut at = 0usize;
        for _ in 0..n {
            let byte = seed.get(at).copied().unwrap_or(0) as usize;
            let byte2 = seed.get(at + 1).copied().unwrap_or(0) as usize;
            at += 2;
            let i = ((byte << 8) | byte2) % deck.len();
            picks.push(deck.swap_remove(i));
        }
        picks
    }

    proptest::proptest! {
        #![proptest_config(proptest::prelude::ProptestConfig::with_cases(20000))]

        #[test]
        fn five_card_order_matches_a_naive_scorer(seed in proptest::collection::vec(proptest::prelude::any::<u8>(), 20..=20)) {
            let a = distinct_cards(&seed[..10], 5);
            let b = distinct_cards(&seed[10..], 5);
            proptest::prop_assert_eq!(
                evaluate(&a).unwrap().cmp(&evaluate(&b).unwrap()),
                naive_score(&a).cmp(&naive_score(&b)),
                "{:?} vs {:?}", a, b
            );
        }

        #[test]
        fn seven_cards_equal_the_best_of_all_five_card_subsets(seed in proptest::collection::vec(proptest::prelude::any::<u8>(), 14..=14)) {
            let cards = distinct_cards(&seed, 7);
            let mut best = None;
            for skip_a in 0..7 {
                for skip_b in skip_a + 1..7 {
                    let five: Vec<Card> = cards.iter().enumerate()
                        .filter(|(i, _)| *i != skip_a && *i != skip_b)
                        .map(|(_, c)| *c).collect();
                    let score = (naive_score(&five), evaluate(&five).unwrap());
                    best = Some(best.map_or(score.clone(), |b: (Vec<u8>, HandRank)| if score.0 > b.0 { score } else { b }));
                }
            }
            proptest::prop_assert_eq!(evaluate(&cards).unwrap(), best.unwrap().1, "{:?}", cards);
        }
    }

    fn full_deck() -> Vec<Card> {
        let mut deck = Vec::new();
        for rank in [
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
        ] {
            for suit in [Suit::Clubs, Suit::Diamonds, Suit::Hearts, Suit::Spades] {
                deck.push(Card { rank, suit });
            }
        }
        deck
    }

    /// Enumerate every `k`-subset of the deck and count categories.
    fn category_counts(k: usize) -> [u64; 9] {
        let deck = full_deck();
        let mut counts = [0u64; 9];
        let mut chosen = Vec::with_capacity(k);
        fn recurse(
            deck: &[Card],
            start: usize,
            k: usize,
            chosen: &mut Vec<Card>,
            counts: &mut [u64; 9],
        ) {
            if chosen.len() == k {
                counts[evaluate(chosen).unwrap().category() as usize] += 1;
                return;
            }
            for i in start..deck.len() {
                chosen.push(deck[i]);
                recurse(deck, i + 1, k, chosen, counts);
                chosen.pop();
            }
        }
        recurse(&deck, 0, k, &mut chosen, &mut counts);
        counts
    }

    #[test]
    fn all_2598960_five_card_hands_match_the_known_distribution() {
        // Well-known combinatorial counts, from HighCard up to StraightFlush
        // (royal flushes are included in straight flushes: 40 = 36 + 4).
        assert_eq!(
            category_counts(5),
            [1_302_540, 1_098_240, 123_552, 54_912, 10_200, 5_108, 3_744, 624, 40]
        );
    }

    /// 133,784,560 hands: run with `cargo test --release -- --ignored seven`.
    #[test]
    #[ignore = "exhaustive seven-card enumeration; run in release mode"]
    fn all_seven_card_hands_match_the_known_distribution() {
        assert_eq!(
            category_counts(7),
            [
                23_294_460, 58_627_800, 31_433_400, 6_461_620, 6_180_020, 4_047_644, 3_473_184,
                224_848, 41_584
            ]
        );
    }
}
