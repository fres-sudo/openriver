//! Test-only construction of valid hands. Everything built here is checked by
//! the real `validate_hand`, so a test cannot silently rely on an impossible hand.

use openriver_domain::*;
use std::collections::{BTreeMap, BTreeSet};

pub struct Table {
    capacity: u8,
    button: Option<u8>,
    small_blind: i64,
    big_blind: i64,
    ante: i64,
    stacks: BTreeMap<u8, i64>,
    starting: BTreeMap<u8, i64>,
    totals: BTreeMap<u8, i64>,
    street_totals: BTreeMap<u8, i64>,
    folded: BTreeSet<u8>,
    all_in: BTreeSet<u8>,
    actions: Vec<ActionEvent>,
    street: Street,
    board: Vec<BoardEvent>,
    deck: Vec<Card>,
    pub bb_seat: u8,
}

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

impl Table {
    /// Seats are `(seat, stack)`. The button seat may be empty (dead button).
    /// Blinds are taken from the seats clockwise after the button.
    pub fn new(
        seats: &[(u8, i64)],
        button: u8,
        capacity: u8,
        small_blind: i64,
        big_blind: i64,
    ) -> Self {
        Self::with_ante(seats, button, capacity, small_blind, big_blind, 0)
    }

    pub fn with_ante(
        seats: &[(u8, i64)],
        button: u8,
        capacity: u8,
        small_blind: i64,
        big_blind: i64,
        ante: i64,
    ) -> Self {
        let mut order: Vec<u8> = seats.iter().map(|(seat, _)| *seat).collect();
        order.sort_unstable();
        // Clockwise starting just after the button.
        let after: Vec<u8> = order
            .iter()
            .copied()
            .filter(|seat| *seat > button)
            .chain(order.iter().copied().filter(|seat| *seat <= button))
            .collect();
        let heads_up = order.len() == 2;
        let (sb_seat, bb_seat) = if heads_up && order.contains(&button) {
            (button, after[0])
        } else {
            (after[0], after[1])
        };
        let stacks: BTreeMap<u8, i64> = seats.iter().copied().collect();
        let zero: BTreeMap<u8, i64> = stacks.keys().map(|seat| (*seat, 0)).collect();
        let mut deck: Vec<Card> = RANKS
            .iter()
            .flat_map(|rank| {
                SUITS.iter().map(|suit| Card {
                    rank: *rank,
                    suit: *suit,
                })
            })
            .collect();
        // Fixed permutation: deterministic and free of duplicates.
        let mut state = 0x2545_F491_4F6C_DD1Du64;
        for i in (1..deck.len()).rev() {
            state ^= state << 13;
            state ^= state >> 7;
            state ^= state << 17;
            deck.swap(i, (state % (i as u64 + 1)) as usize);
        }
        let mut table = Self {
            capacity,
            button: Some(button),
            small_blind,
            big_blind,
            ante,
            starting: stacks.clone(),
            stacks,
            totals: zero.clone(),
            street_totals: zero,
            folded: BTreeSet::new(),
            all_in: BTreeSet::new(),
            actions: Vec::new(),
            street: Street::Preflop,
            board: Vec::new(),
            deck,
            bb_seat,
        };
        if ante > 0 {
            for seat in order {
                table.push(
                    seat,
                    ActionKind::PostAnte {
                        amount_added: Chips(0),
                    },
                    0,
                );
                let amount = ante.min(table.stacks[&seat]);
                table.pay(seat, amount, true);
                if let Some(ActionEvent {
                    kind: ActionKind::PostAnte { amount_added },
                    all_in,
                    ..
                }) = table.actions.last_mut()
                {
                    *amount_added = Chips(amount);
                    *all_in = table.stacks[&seat] == 0;
                }
                if table.stacks[&seat] == 0 {
                    table.all_in.insert(seat);
                }
            }
        }
        table.post(sb_seat, small_blind, true);
        table.post(bb_seat, big_blind, false);
        table
    }

    fn push(&mut self, seat: u8, kind: ActionKind, _unused: u8) {
        let sequence = self.actions.len() as u32;
        self.actions.push(ActionEvent {
            sequence,
            street: self.street,
            seat,
            kind,
            all_in: false,
        });
    }

    /// Move chips from the stack; antes do not count toward the street.
    fn pay(&mut self, seat: u8, amount: i64, ante: bool) {
        *self.stacks.get_mut(&seat).unwrap() -= amount;
        *self.totals.get_mut(&seat).unwrap() += amount;
        if !ante {
            *self.street_totals.get_mut(&seat).unwrap() += amount;
        }
    }

    fn post(&mut self, seat: u8, blind: i64, small: bool) {
        let amount = blind.min(self.stacks[&seat]);
        self.pay(seat, amount, false);
        let all_in = self.stacks[&seat] == 0;
        let amount_added = Chips(amount);
        self.actions.push(ActionEvent {
            sequence: self.actions.len() as u32,
            street: Street::Preflop,
            seat,
            kind: if small {
                ActionKind::PostSmallBlind { amount_added }
            } else {
                ActionKind::PostBigBlind { amount_added }
            },
            all_in,
        });
        if all_in {
            self.all_in.insert(seat);
        }
    }

    pub fn highest(&self) -> i64 {
        self.street_totals.values().copied().max().unwrap_or(0)
    }

    pub fn outstanding(&self, seat: u8) -> i64 {
        self.highest() - self.street_totals[&seat]
    }

    pub fn stack(&self, seat: u8) -> i64 {
        self.stacks[&seat]
    }

    pub fn street_total(&self, seat: u8) -> i64 {
        self.street_totals[&seat]
    }

    pub fn is_folded(&self, seat: u8) -> bool {
        self.folded.contains(&seat)
    }

    pub fn is_all_in(&self, seat: u8) -> bool {
        self.all_in.contains(&seat)
    }

    pub fn street(&self) -> Street {
        self.street
    }

    pub fn live_seats(&self) -> Vec<u8> {
        self.stacks
            .keys()
            .copied()
            .filter(|seat| !self.folded.contains(seat))
            .collect()
    }

    fn act(&mut self, seat: u8, kind: ActionKind, delta: i64) {
        self.pay(seat, delta, false);
        let all_in = self.stacks[&seat] == 0 && delta > 0;
        self.actions.push(ActionEvent {
            sequence: self.actions.len() as u32,
            street: self.street,
            seat,
            kind,
            all_in,
        });
        if all_in {
            self.all_in.insert(seat);
        }
    }

    pub fn fold(&mut self, seat: u8) -> &mut Self {
        self.act(seat, ActionKind::Fold, 0);
        self.folded.insert(seat);
        self
    }

    pub fn check(&mut self, seat: u8) -> &mut Self {
        self.act(seat, ActionKind::Check, 0);
        self
    }

    /// Calls for the outstanding amount, or all-in for less.
    pub fn call(&mut self, seat: u8) -> &mut Self {
        let amount = self.outstanding(seat).min(self.stacks[&seat]);
        self.act(
            seat,
            ActionKind::Call {
                amount_added: Chips(amount),
            },
            amount,
        );
        self
    }

    /// Opens the betting on a street with `amount` chips (capped at the stack).
    pub fn bet(&mut self, seat: u8, amount: i64) -> &mut Self {
        let amount = amount.min(self.stacks[&seat]);
        self.act(
            seat,
            ActionKind::Bet {
                amount_added: Chips(amount),
            },
            amount,
        );
        self
    }

    /// Raises so the player's total contribution on this street is `to`.
    pub fn raise_to(&mut self, seat: u8, to: i64) -> &mut Self {
        let cap = self.street_totals[&seat] + self.stacks[&seat];
        let to = to.min(cap);
        let delta = to - self.street_totals[&seat];
        self.act(
            seat,
            ActionKind::RaiseTo {
                total_street_contribution: Chips(to),
            },
            delta,
        );
        self
    }

    /// Return the unmatched part of the biggest contribution on this street.
    pub fn close_street(&mut self) -> &mut Self {
        let mut sorted: Vec<(i64, u8)> = self
            .street_totals
            .iter()
            .map(|(seat, total)| (*total, *seat))
            .collect();
        sorted.sort_unstable_by(|a, b| b.cmp(a));
        if sorted.len() >= 2 && sorted[0].0 > sorted[1].0 {
            let (top, seat) = sorted[0];
            let amount = top - sorted[1].0;
            *self.stacks.get_mut(&seat).unwrap() += amount;
            *self.totals.get_mut(&seat).unwrap() -= amount;
            *self.street_totals.get_mut(&seat).unwrap() -= amount;
            self.actions.push(ActionEvent {
                sequence: self.actions.len() as u32,
                street: self.street,
                seat,
                kind: ActionKind::ReturnUncalled {
                    amount: Chips(amount),
                },
                all_in: false,
            });
        }
        self
    }

    /// Close the current street and deal the next one.
    pub fn next_street(&mut self) -> &mut Self {
        self.close_street();
        let (next, count) = match self.street {
            Street::Preflop => (Street::Flop, 3),
            Street::Flop => (Street::Turn, 1),
            Street::Turn => (Street::River, 1),
            _ => panic!("no street after the river"),
        };
        let cards = self.deck.split_off(self.deck.len() - count);
        self.board.push(BoardEvent {
            street: next,
            cards,
        });
        self.street = next;
        self.street_totals.values_mut().for_each(|v| *v = 0);
        self
    }

    /// Deal every remaining street, as histories do for all-in run-outs.
    pub fn run_out(&mut self) -> &mut Self {
        while self.street != Street::River {
            self.next_street();
        }
        self
    }

    /// Build the hand. `winner` picks the awarded seats for each pot as
    /// `(seat, share)` pairs whose shares are split in proportion; `rake` is
    /// removed from the pots in order (clamped so no pot is emptied).
    pub fn finish(mut self, rake: i64, mut winner: impl FnMut(usize, &Pot) -> Vec<u8>) -> Hand {
        self.close_street();
        let mut levels: Vec<i64> = self.totals.values().copied().filter(|v| *v > 0).collect();
        levels.sort_unstable();
        levels.dedup();
        let mut lower = 0;
        let mut pots = Vec::new();
        for upper in levels {
            let contributors: Vec<u8> = self
                .totals
                .iter()
                .filter(|(_, total)| **total >= upper)
                .map(|(seat, _)| *seat)
                .collect();
            let eligible_seats = contributors
                .iter()
                .copied()
                .filter(|seat| !self.folded.contains(seat))
                .collect();
            pots.push(Pot {
                amount: Chips((upper - lower) * contributors.len() as i64),
                eligible_seats,
            });
            lower = upper;
        }
        // Rake never empties a pot, so clamp it to what the pots can bear.
        let rake = rake.min(pots.iter().map(|pot| pot.amount.0 - 1).sum());
        let mut awards = Vec::new();
        let mut rake_left = rake;
        for (index, pot) in pots.iter().enumerate() {
            let winners = winner(index, pot);
            assert!(!winners.is_empty(), "every pot needs a winner");
            let mut pot_amount = pot.amount.0;
            let take = rake_left.min(pot_amount - 1);
            pot_amount -= take;
            rake_left -= take;
            let share = pot_amount / winners.len() as i64;
            let mut remainder = pot_amount - share * winners.len() as i64;
            for seat in winners {
                let extra = remainder.min(1);
                remainder -= extra;
                awards.push(Award {
                    pot_index: index,
                    seat,
                    amount: Chips(share + extra),
                });
            }
        }
        assert_eq!(rake_left, 0, "rake did not fit in the pots");
        let hand = Hand {
            game: GameDefinition {
                variant: GameVariant::NoLimitHoldem,
                currency: "USD".into(),
                currency_scale: 2,
                small_blind: Chips(self.small_blind),
                big_blind: Chips(self.big_blind),
                ante: Chips(self.ante),
                table_capacity: self.capacity,
            },
            provenance: Provenance {
                room: "testkit".into(),
                external_hand_id: "1".into(),
                parser_version: "test".into(),
                source_sha256: "test".into(),
                start_line: 1,
                end_line: 2,
            },
            table_name: "Test".into(),
            played_at: "2026-01-01T00:00:00Z".into(),
            players: self
                .starting
                .iter()
                .map(|(seat, stack)| PlayerAtSeat {
                    seat: *seat,
                    name: format!("P{seat}"),
                    starting_stack: Chips(*stack),
                    hole_cards: None,
                })
                .collect(),
            actions: self.actions,
            board: self.board,
            pots,
            awards,
            rake: Chips(rake),
            button_seat: self.button,
        };
        if let Err(error) = validate_hand(&hand) {
            panic!("testkit built an invalid hand: {error:?}\n{hand:#?}");
        }
        hand
    }

    /// Everything-goes-to-the-first-eligible-player convenience.
    pub fn finish_first_wins(self) -> Hand {
        self.finish(0, |_, pot| vec![pot.eligible_seats[0]])
    }
}

/// Plays random but legal no-limit hands, driven by caller-supplied entropy so
/// property tests shrink well.
pub struct Entropy<'a> {
    bytes: &'a [u8],
    at: usize,
}

impl<'a> Entropy<'a> {
    pub fn new(bytes: &'a [u8]) -> Self {
        Self { bytes, at: 0 }
    }

    pub fn next(&mut self) -> u32 {
        if self.bytes.is_empty() {
            return 0;
        }
        let value = self.bytes[self.at % self.bytes.len()];
        self.at += 1;
        u32::from(value)
    }

    /// A value in `0..n`.
    pub fn below(&mut self, n: u32) -> u32 {
        if n <= 1 {
            return 0;
        }
        // Two bytes keep small `n` unbiased enough and large `n` reachable.
        let wide = (self.next() << 8) | self.next();
        wide % n
    }
}

pub struct Setup {
    pub seats: Vec<(u8, i64)>,
    pub button: u8,
    pub capacity: u8,
    pub small_blind: i64,
    pub big_blind: i64,
    pub ante: i64,
}

pub fn simulate(setup: &Setup, entropy: &mut Entropy) -> Hand {
    let mut table = Table::with_ante(
        &setup.seats,
        setup.button,
        setup.capacity,
        setup.small_blind,
        setup.big_blind,
        setup.ante,
    );
    let mut order: Vec<u8> = setup.seats.iter().map(|(seat, _)| *seat).collect();
    order.sort_unstable();
    let clockwise_from = |start: u8| -> Vec<u8> {
        order
            .iter()
            .copied()
            .filter(|seat| *seat > start)
            .chain(order.iter().copied().filter(|seat| *seat <= start))
            .collect()
    };
    let big_blind = setup.big_blind;
    // Per-hand temper: (fold %, call-or-below %, check %, all-in 1-in-N)
    let (fold_at, call_at, check_at, jam) = match entropy.below(3) {
        0 => (45, 90, 80, 12), // tight and passive
        1 => (30, 82, 65, 8),  // ordinary
        _ => (15, 60, 45, 3),  // loose and wild
    };
    loop {
        let street = table.street();
        // Preflop action starts after the big blind; later streets after the button.
        let start = if street == Street::Preflop {
            table.bb_seat
        } else {
            setup.button
        };
        let mut pending: std::collections::VecDeque<u8> = clockwise_from(start).into();
        let mut last_raise_size = big_blind;
        let mut highest_at_last_raise = table.highest();
        while let Some(seat) = pending.pop_front() {
            if table.live_seats().len() < 2 {
                break;
            }
            if table.is_folded(seat) || table.is_all_in(seat) {
                continue;
            }
            // Nobody left to bet against.
            let able: Vec<u8> = table
                .live_seats()
                .into_iter()
                .filter(|s| !table.is_all_in(*s))
                .collect();
            if able.len() == 1 && table.outstanding(seat) == 0 {
                break;
            }
            let outstanding = table.outstanding(seat);
            let stack = table.stack(seat);
            let mine = table.street_total(seat);
            let highest = table.highest();
            let choice = entropy.below(100);
            let mut raised = false;
            if outstanding == 0 {
                if choice < check_at {
                    table.check(seat);
                } else if highest == 0 {
                    let amount = pick_size(entropy, big_blind, stack, stack, jam);
                    table.bet(seat, amount);
                    raised = true;
                } else {
                    let to = pick_raise(
                        entropy,
                        highest,
                        last_raise_size,
                        big_blind,
                        mine + stack,
                        jam,
                    );
                    table.raise_to(seat, to);
                    raised = true;
                }
            } else if choice < fold_at {
                table.fold(seat);
            } else if choice < call_at || stack <= outstanding {
                table.call(seat);
            } else {
                let to = pick_raise(
                    entropy,
                    highest,
                    last_raise_size,
                    big_blind,
                    mine + stack,
                    jam,
                );
                table.raise_to(seat, to);
                raised = true;
            }
            if raised {
                let new_highest = table.highest();
                last_raise_size = (new_highest - highest_at_last_raise).max(big_blind);
                highest_at_last_raise = new_highest;
                pending = clockwise_from(seat).into();
            }
        }
        if table.live_seats().len() < 2 || street == Street::River {
            break;
        }
        table.next_street();
    }
    if table.live_seats().len() >= 2 {
        table.run_out();
    }
    let pick = entropy.below(1000);
    let max_rake = 3;
    let rake = if table.live_seats().len() >= 2 || pick % 2 == 0 {
        0
    } else {
        i64::from(pick as u8 % (max_rake + 1))
    };
    let seed = [pick as u8, (pick >> 3) as u8, 7];
    let mut winner_entropy = Entropy::new(&seed);
    table.finish(rake, |_, pot| {
        let eligible = &pot.eligible_seats;
        let first = eligible[winner_entropy.below(eligible.len() as u32) as usize];
        if eligible.len() > 1 && winner_entropy.below(5) == 0 {
            let second = eligible[winner_entropy.below(eligible.len() as u32) as usize];
            if second != first {
                return vec![first, second];
            }
        }
        vec![first]
    })
}

fn pick_size(entropy: &mut Entropy, min: i64, stack: i64, cap: i64, jam: u32) -> i64 {
    let max = stack.min(cap);
    if max <= min {
        return max;
    }
    match entropy.below(jam) {
        0 => max, // all-in
        _ => min + i64::from(entropy.below((max - min + 1) as u32)),
    }
}

fn pick_raise(
    entropy: &mut Entropy,
    highest: i64,
    last_raise: i64,
    big_blind: i64,
    cap: i64,
    jam: u32,
) -> i64 {
    let min_to = highest + last_raise.max(big_blind);
    if cap <= min_to {
        return cap;
    }
    match entropy.below(jam) {
        0 => cap,
        _ => min_to + i64::from(entropy.below((cap - min_to + 1) as u32)),
    }
}
