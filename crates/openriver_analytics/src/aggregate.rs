//! Accumulating statistics over many hands, per player, with filters.
//!
//! Everything here is a commutative monoid: observing hands one at a time,
//! or merging aggregates built from disjoint hand sets, gives the same result.

use crate::analysis::{analyze, Act, AnalysisError, HandAnalysis, PlayerSummary};
use crate::position::{Position, PositionGroup};
use crate::stats::Stat;
use crate::OpportunityCount;
use openriver_domain::{Hand, Street};
use std::collections::{BTreeMap, BTreeSet};

/// Postflop action counts, from which aggression measures are derived.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct AggressionCounts {
    pub bets: u64,
    pub raises: u64,
    pub calls: u64,
    pub checks: u64,
    pub folds: u64,
}

impl AggressionCounts {
    pub fn observe(&mut self, act: Act) {
        match act {
            Act::Bet => self.bets += 1,
            Act::Raise => self.raises += 1,
            Act::Call => self.calls += 1,
            Act::Check => self.checks += 1,
            Act::Fold => self.folds += 1,
        }
    }

    pub fn merge(&mut self, other: &Self) {
        self.bets += other.bets;
        self.raises += other.raises;
        self.calls += other.calls;
        self.checks += other.checks;
        self.folds += other.folds;
    }

    pub fn aggressive(&self) -> u64 {
        self.bets + self.raises
    }

    /// (bets + raises) / calls. `None` with no calls: the ratio is undefined, not zero.
    pub fn factor(&self) -> Option<f64> {
        (self.calls != 0).then(|| self.aggressive() as f64 / self.calls as f64)
    }

    /// (bets + raises) / all postflop decisions. `None` with no decisions.
    pub fn frequency(&self) -> Option<f64> {
        let total = self.aggressive() + self.calls + self.checks + self.folds;
        (total != 0).then(|| self.aggressive() as f64 / total as f64)
    }
}

/// Results are kept per currency and decimal scale: units are never mixed.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Money {
    pub hands: u64,
    /// Net chips won, in minor units per currency.
    pub net: BTreeMap<(String, u8), i64>,
    /// Net chips won at showdown / without showdown, per currency.
    pub net_at_showdown: BTreeMap<(String, u8), i64>,
    pub net_without_showdown: BTreeMap<(String, u8), i64>,
    /// Sum over hands of net / big blind, comparable across stakes.
    pub net_big_blinds: f64,
}

impl Money {
    fn observe(&mut self, analysis: &HandAnalysis, player: &PlayerSummary) {
        let key = (analysis.currency.clone(), analysis.currency_scale);
        self.hands += 1;
        *self.net.entry(key.clone()).or_insert(0) += player.net;
        let bucket = if player.went_to_showdown {
            &mut self.net_at_showdown
        } else {
            &mut self.net_without_showdown
        };
        *bucket.entry(key).or_insert(0) += player.net;
        self.net_big_blinds += player.net as f64 / analysis.big_blind as f64;
    }

    fn merge(&mut self, other: &Self) {
        self.hands += other.hands;
        for (mine, theirs) in [
            (&mut self.net, &other.net),
            (&mut self.net_at_showdown, &other.net_at_showdown),
            (&mut self.net_without_showdown, &other.net_without_showdown),
        ] {
            for (key, value) in theirs {
                *mine.entry(key.clone()).or_insert(0) += value;
            }
        }
        self.net_big_blinds += other.net_big_blinds;
    }

    /// Big blinds won per 100 hands. `None` without hands.
    pub fn bb_per_100(&self) -> Option<f64> {
        (self.hands != 0).then(|| self.net_big_blinds * 100.0 / self.hands as f64)
    }
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct PlayerStats {
    pub hands: u64,
    stats: BTreeMap<Stat, OpportunityCount>,
    pub postflop: AggressionCounts,
    pub money: Money,
}

impl PlayerStats {
    pub fn get(&self, stat: Stat) -> OpportunityCount {
        self.stats.get(&stat).copied().unwrap_or_default()
    }

    pub fn observe(&mut self, analysis: &HandAnalysis, player: &PlayerSummary) {
        self.hands += 1;
        for stat in Stat::ALL {
            if let Some(taken) = stat.evaluate(analysis, player) {
                self.stats.entry(stat).or_default().observe(taken);
            }
        }
        for decision in analysis.decisions_of(player.seat) {
            if decision.street != Street::Preflop {
                self.postflop.observe(decision.act);
            }
        }
        self.money.observe(analysis, player);
    }

    pub fn merge(&mut self, other: &Self) {
        self.hands += other.hands;
        for (stat, count) in &other.stats {
            self.stats.entry(*stat).or_default().merge(count);
        }
        self.postflop.merge(&other.postflop);
        self.money.merge(&other.money);
    }
}

/// Which hands and players count. Unset fields do not restrict.
#[derive(Clone, Debug, Default)]
pub struct HandFilter {
    /// Inclusive bounds on `played_at` (normalized `YYYY-MM-DDTHH:MM:SSZ`).
    pub from: Option<String>,
    pub to: Option<String>,
    pub currency: Option<String>,
    /// Inclusive bounds on the big blind, in minor units.
    pub min_big_blind: Option<i64>,
    pub max_big_blind: Option<i64>,
    pub min_players: Option<usize>,
    pub max_players: Option<usize>,
    pub positions: Option<BTreeSet<Position>>,
    pub position_groups: Option<BTreeSet<PositionGroup>>,
    pub rooms: Option<BTreeSet<String>>,
}

impl HandFilter {
    fn hand_matches(&self, hand: &Hand, analysis: &HandAnalysis) -> bool {
        self.from
            .as_ref()
            .is_none_or(|from| analysis.played_at >= *from)
            && self.to.as_ref().is_none_or(|to| analysis.played_at <= *to)
            && self
                .currency
                .as_ref()
                .is_none_or(|currency| *currency == analysis.currency)
            && self
                .min_big_blind
                .is_none_or(|min| analysis.big_blind >= min)
            && self
                .max_big_blind
                .is_none_or(|max| analysis.big_blind <= max)
            && self
                .min_players
                .is_none_or(|min| analysis.players.len() >= min)
            && self
                .max_players
                .is_none_or(|max| analysis.players.len() <= max)
            && self
                .rooms
                .as_ref()
                .is_none_or(|rooms| rooms.contains(&hand.provenance.room))
    }

    /// A position filter excludes players whose position is unknown.
    fn player_matches(&self, player: &PlayerSummary) -> bool {
        let position_ok = self.positions.as_ref().is_none_or(|set| {
            player
                .position
                .is_some_and(|position| set.contains(&position))
        });
        let group_ok = self.position_groups.as_ref().is_none_or(|set| {
            player
                .position
                .is_some_and(|position| set.contains(&position.group()))
        });
        position_ok && group_ok
    }
}

/// Identity of a player: names are only unique within a room.
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct PlayerKey {
    pub room: String,
    pub name: String,
}

/// Feeds hands in and keeps per-player aggregates.
#[derive(Clone, Debug, Default)]
pub struct StatsEngine {
    filter: HandFilter,
    players: BTreeMap<PlayerKey, PlayerStats>,
    hands_seen: u64,
    hands_counted: u64,
}

impl StatsEngine {
    pub fn new(filter: HandFilter) -> Self {
        Self {
            filter,
            ..Self::default()
        }
    }

    /// Analyze and record one hand. Invalid hands are an error and change nothing.
    pub fn add_hand(&mut self, hand: &Hand) -> Result<(), AnalysisError> {
        let analysis = analyze(hand)?;
        self.hands_seen += 1;
        if !self.filter.hand_matches(hand, &analysis) {
            return Ok(());
        }
        self.hands_counted += 1;
        for player in &analysis.players {
            if !self.filter.player_matches(player) {
                continue;
            }
            let key = PlayerKey {
                room: hand.provenance.room.clone(),
                name: player.name.clone(),
            };
            self.players
                .entry(key)
                .or_default()
                .observe(&analysis, player);
        }
        Ok(())
    }

    pub fn player(&self, room: &str, name: &str) -> Option<&PlayerStats> {
        self.players.get(&PlayerKey {
            room: room.into(),
            name: name.into(),
        })
    }

    pub fn players(&self) -> impl Iterator<Item = (&PlayerKey, &PlayerStats)> {
        self.players.iter()
    }

    pub fn hands_seen(&self) -> u64 {
        self.hands_seen
    }

    /// Hands that passed the hand-level filter.
    pub fn hands_counted(&self) -> u64 {
        self.hands_counted
    }

    /// Combine engines built with the same filter over disjoint hands.
    pub fn merge(&mut self, other: &Self) {
        self.hands_seen += other.hands_seen;
        self.hands_counted += other.hands_counted;
        for (key, stats) in &other.players {
            self.players.entry(key.clone()).or_default().merge(stats);
        }
    }
}
