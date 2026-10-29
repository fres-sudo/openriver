//! Statistic definitions. Each is an explicit opportunity: who is eligible
//! (the denominator) and who took it (the numerator), evaluated per player per hand.
//!
//! Definitions are versioned: when a rule changes, bump [`Stat::version`] so
//! stored aggregates can be recomputed rather than silently mixed.

use crate::analysis::{Act, Decision, HandAnalysis, PlayerSummary};
use crate::position::Position;
use openriver_domain::Street;

/// `None`: not eligible this hand. `Some(true)`: took the opportunity.
pub type Outcome = Option<bool>;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum Stat {
    Vpip,
    Pfr,
    RaiseFirstIn,
    OpenLimp,
    ThreeBet,
    FoldToThreeBet,
    FourBet,
    FoldToFourBet,
    ColdCall,
    StealAttempt,
    FoldSmallBlindToSteal,
    FoldBigBlindToSteal,
    ThreeBetVsSteal,
    SawFlop,
    CBetFlop,
    FoldToCBetFlop,
    CBetTurn,
    CheckRaiseFlop,
    WentToShowdown,
    WonAtShowdown,
    WonWhenSawFlop,
}

impl Stat {
    pub const ALL: [Stat; 21] = [
        Stat::Vpip,
        Stat::Pfr,
        Stat::RaiseFirstIn,
        Stat::OpenLimp,
        Stat::ThreeBet,
        Stat::FoldToThreeBet,
        Stat::FourBet,
        Stat::FoldToFourBet,
        Stat::ColdCall,
        Stat::StealAttempt,
        Stat::FoldSmallBlindToSteal,
        Stat::FoldBigBlindToSteal,
        Stat::ThreeBetVsSteal,
        Stat::SawFlop,
        Stat::CBetFlop,
        Stat::FoldToCBetFlop,
        Stat::CBetTurn,
        Stat::CheckRaiseFlop,
        Stat::WentToShowdown,
        Stat::WonAtShowdown,
        Stat::WonWhenSawFlop,
    ];

    /// Stable machine key; safe to store.
    pub fn key(self) -> &'static str {
        match self {
            Stat::Vpip => "vpip",
            Stat::Pfr => "pfr",
            Stat::RaiseFirstIn => "rfi",
            Stat::OpenLimp => "open_limp",
            Stat::ThreeBet => "three_bet",
            Stat::FoldToThreeBet => "fold_to_three_bet",
            Stat::FourBet => "four_bet",
            Stat::FoldToFourBet => "fold_to_four_bet",
            Stat::ColdCall => "cold_call",
            Stat::StealAttempt => "steal",
            Stat::FoldSmallBlindToSteal => "fold_sb_to_steal",
            Stat::FoldBigBlindToSteal => "fold_bb_to_steal",
            Stat::ThreeBetVsSteal => "three_bet_vs_steal",
            Stat::SawFlop => "saw_flop",
            Stat::CBetFlop => "cbet_flop",
            Stat::FoldToCBetFlop => "fold_to_cbet_flop",
            Stat::CBetTurn => "cbet_turn",
            Stat::CheckRaiseFlop => "check_raise_flop",
            Stat::WentToShowdown => "wtsd",
            Stat::WonAtShowdown => "wsd",
            Stat::WonWhenSawFlop => "wwsf",
        }
    }

    pub fn label(self) -> &'static str {
        match self {
            Stat::Vpip => "VPIP",
            Stat::Pfr => "PFR",
            Stat::RaiseFirstIn => "Raise first in",
            Stat::OpenLimp => "Open limp",
            Stat::ThreeBet => "3-bet",
            Stat::FoldToThreeBet => "Fold to 3-bet",
            Stat::FourBet => "4-bet",
            Stat::FoldToFourBet => "Fold to 4-bet",
            Stat::ColdCall => "Cold call",
            Stat::StealAttempt => "Steal attempt",
            Stat::FoldSmallBlindToSteal => "Small blind fold to steal",
            Stat::FoldBigBlindToSteal => "Big blind fold to steal",
            Stat::ThreeBetVsSteal => "Blind 3-bet vs steal",
            Stat::SawFlop => "Saw flop",
            Stat::CBetFlop => "Flop c-bet",
            Stat::FoldToCBetFlop => "Fold to flop c-bet",
            Stat::CBetTurn => "Turn c-bet",
            Stat::CheckRaiseFlop => "Flop check-raise",
            Stat::WentToShowdown => "Went to showdown",
            Stat::WonAtShowdown => "Won at showdown",
            Stat::WonWhenSawFlop => "Won when saw flop",
        }
    }

    /// Plain-language eligibility and success rules.
    pub fn description(self) -> &'static str {
        match self {
            Stat::Vpip => "Of all hands dealt in, how often the player voluntarily put chips in preflop (call, bet or raise; blinds and checks do not count).",
            Stat::Pfr => "Of all hands dealt in, how often the player raised preflop.",
            Stat::RaiseFirstIn => "When everyone before had folded and the player faced only the blinds, how often they raised.",
            Stat::OpenLimp => "When everyone before had folded and the player faced only the blinds, how often they limped.",
            Stat::ThreeBet => "When facing exactly one preflop raise with chips behind, how often the player re-raised.",
            Stat::FoldToThreeBet => "After raising preflop and then facing exactly a 3-bet, how often the player folded.",
            Stat::FourBet => "When facing exactly a 3-bet preflop with chips behind, how often the player re-raised.",
            Stat::FoldToFourBet => "After 3-betting preflop and then facing exactly a 4-bet, how often the player folded.",
            Stat::ColdCall => "When first to voluntarily act against a raise, from outside the blinds, how often the player called.",
            Stat::StealAttempt => "When first in from the cutoff, button or small blind, how often the player raised.",
            Stat::FoldSmallBlindToSteal => "When the small blind faced a steal raise that no one had called, how often they folded.",
            Stat::FoldBigBlindToSteal => "When the big blind faced a steal raise that no one had called, how often they folded.",
            Stat::ThreeBetVsSteal => "When a blind faced a steal raise that no one had called and could re-raise, how often they did.",
            Stat::SawFlop => "Of all hands dealt in, how often the player was still in when the flop came.",
            Stat::CBetFlop => "As the last preflop raiser acting first on an unbet flop with an opponent able to respond, how often the player bet.",
            Stat::FoldToCBetFlop => "When facing a flop bet from the last preflop raiser, how often the player folded.",
            Stat::CBetTurn => "After c-betting the flop and acting first on an unbet turn with an opponent able to respond, how often the player bet again.",
            Stat::CheckRaiseFlop => "After checking the flop and then facing a bet, how often the player raised.",
            Stat::WentToShowdown => "Of hands where the player saw the flop, how often they reached showdown.",
            Stat::WonAtShowdown => "Of showdowns the player reached, how often they won a share of the pot.",
            Stat::WonWhenSawFlop => "Of hands where the player saw the flop, how often they won a share of the pot.",
        }
    }

    /// Bump when the eligibility or success rule changes.
    pub fn version(self) -> u32 {
        1
    }

    /// Rough denominator below which a rate is mostly noise. Guidance only.
    pub fn minimum_meaningful_sample(self) -> u64 {
        match self {
            Stat::Vpip | Stat::Pfr | Stat::SawFlop => 100,
            Stat::RaiseFirstIn | Stat::OpenLimp | Stat::StealAttempt | Stat::ThreeBet => 100,
            _ => 50,
        }
    }

    pub fn evaluate(self, analysis: &HandAnalysis, player: &PlayerSummary) -> Outcome {
        let ctx = Ctx::new(analysis, player);
        match self {
            Stat::Vpip => Some(
                ctx.preflop()
                    .any(|d| matches!(d.act, Act::Call | Act::Bet | Act::Raise)),
            ),
            Stat::Pfr => Some(ctx.preflop().any(|d| d.act == Act::Raise)),
            Stat::RaiseFirstIn => ctx.first_in_opportunity().map(|d| d.act == Act::Raise),
            Stat::OpenLimp => ctx.first_in_opportunity().map(|d| d.act == Act::Call),
            Stat::ThreeBet => ctx.facing_level(2).map(|d| d.act == Act::Raise),
            Stat::FoldToThreeBet => ctx.fold_to_reraise(1, 3),
            Stat::FourBet => ctx.facing_level(3).map(|d| d.act == Act::Raise),
            Stat::FoldToFourBet => ctx.fold_to_reraise(2, 4),
            Stat::ColdCall => ctx
                .preflop()
                .find(|d| d.first_decision_of_hand)
                .filter(|d| d.bet_level_before >= 2 && !player.posted_blind && d.to_call > 0)
                .map(|d| d.act == Act::Call),
            Stat::StealAttempt => ctx
                .first_in_opportunity()
                .filter(|_| player.position.is_some_and(Position::is_steal_position))
                .map(|d| d.act == Act::Raise),
            Stat::FoldSmallBlindToSteal => ctx.blind_vs_steal(Position::SmallBlind, Act::Fold),
            Stat::FoldBigBlindToSteal => ctx.blind_vs_steal(Position::BigBlind, Act::Fold),
            Stat::ThreeBetVsSteal => ctx
                .blind_decision_vs_steal()
                .filter(|d| d.could_raise())
                .map(|d| d.act == Act::Raise),
            Stat::SawFlop => Some(player.saw_flop),
            Stat::CBetFlop => ctx
                .is_preflop_aggressor()
                .then(|| ctx.first_on(Street::Flop))
                .flatten()
                .filter(|d| d.bet_level_before == 0 && d.opponents_with_chips >= 1)
                .map(|d| d.act == Act::Bet),
            Stat::FoldToCBetFlop => ctx
                .on(Street::Flop)
                .find(|d| {
                    d.bet_level_before == 1
                        && d.aggressor.is_some()
                        && d.aggressor == analysis.preflop_aggressor
                        && d.aggressor != Some(d.seat)
                })
                .map(|d| d.act == Act::Fold),
            Stat::CBetTurn => {
                let flop_cbet = ctx.is_preflop_aggressor()
                    && ctx
                        .first_on(Street::Flop)
                        .is_some_and(|d| d.bet_level_before == 0 && d.act == Act::Bet);
                flop_cbet
                    .then(|| ctx.first_on(Street::Turn))
                    .flatten()
                    .filter(|d| d.bet_level_before == 0 && d.opponents_with_chips >= 1)
                    .map(|d| d.act == Act::Bet)
            }
            Stat::CheckRaiseFlop => {
                let mut checked = false;
                for d in ctx.on(Street::Flop) {
                    if d.bet_level_before == 0 && d.act == Act::Check {
                        checked = true;
                    } else if checked && d.bet_level_before == 1 && d.could_raise() {
                        return Some(d.act == Act::Raise);
                    }
                }
                None
            }
            Stat::WentToShowdown => player.saw_flop.then_some(player.went_to_showdown),
            Stat::WonAtShowdown => player.went_to_showdown.then_some(player.collected > 0),
            Stat::WonWhenSawFlop => player.saw_flop.then_some(player.collected > 0),
        }
    }
}

/// Per-player view of a hand's decisions used by definitions.
struct Ctx<'a> {
    analysis: &'a HandAnalysis,
    player: &'a PlayerSummary,
}

impl<'a> Ctx<'a> {
    fn new(analysis: &'a HandAnalysis, player: &'a PlayerSummary) -> Self {
        Self { analysis, player }
    }

    fn mine(&self) -> impl Iterator<Item = &'a Decision> {
        self.analysis.decisions_of(self.player.seat)
    }

    fn preflop(&self) -> impl Iterator<Item = &'a Decision> {
        self.on(Street::Preflop)
    }

    fn on(&self, street: Street) -> impl Iterator<Item = &'a Decision> {
        self.mine().filter(move |d| d.street == street)
    }

    fn first_on(&self, street: Street) -> Option<&'a Decision> {
        self.on(street).next()
    }

    fn is_preflop_aggressor(&self) -> bool {
        self.analysis.preflop_aggressor == Some(self.player.seat)
    }

    /// First in against only the blinds, with the option to raise.
    fn first_in_opportunity(&self) -> Option<&'a Decision> {
        self.preflop()
            .next()
            .filter(|d| d.first_in && d.bet_level_before == 1 && d.to_call > 0 && d.could_raise())
    }

    /// The player's decision when facing exactly `level` aggressive actions
    /// preflop, if they could have raised.
    fn facing_level(&self, level: u8) -> Option<&'a Decision> {
        self.preflop()
            .find(|d| d.bet_level_before == level && d.could_raise())
    }

    /// Raised when the bet level was `raised_at`, then later faced `faced`.
    fn fold_to_reraise(&self, raised_at: u8, faced: u8) -> Outcome {
        let mut raised = false;
        for d in self.preflop() {
            if raised {
                // Their first decision after raising: only count an exact re-raise.
                return (d.bet_level_before == faced).then_some(d.act == Act::Fold);
            }
            raised = d.act == Act::Raise && d.bet_level_before == raised_at;
        }
        None
    }

    /// The blind's first decision facing an uncalled steal raise.
    fn blind_decision_vs_steal(&self) -> Option<&'a Decision> {
        if !self.player.posted_blind {
            return None;
        }
        let first = self.preflop().find(|d| d.first_decision_of_hand)?;
        if first.bet_level_before != 2 {
            return None;
        }
        self.steal_open_before(first)?;
        Some(first)
    }

    fn blind_vs_steal(&self, position: Position, act: Act) -> Outcome {
        if self.player.position != Some(position) {
            return None;
        }
        self.blind_decision_vs_steal().map(|d| d.act == act)
    }

    /// The open raise this decision faces, if it was a first-in steal that
    /// everyone since has folded to.
    fn steal_open_before(&self, decision: &Decision) -> Option<()> {
        let all = &self.analysis.decisions;
        let at = all
            .iter()
            .position(|d| d.action_index == decision.action_index)?;
        let open_at = all[..at].iter().rposition(|d| {
            d.street == Street::Preflop && d.act == Act::Raise && d.bet_level_before == 1
        })?;
        let open = &all[open_at];
        let opener = self.analysis.player(open.seat)?;
        let is_steal = open.first_in && opener.position.is_some_and(Position::is_steal_position);
        let only_folds_since = all[open_at + 1..at].iter().all(|d| d.act == Act::Fold);
        (is_steal && only_folds_since).then_some(())
    }
}
