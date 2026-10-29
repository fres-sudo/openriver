//! Hand-audited scenarios. Each comment states the poker facts first, then the
//! expected statistic outcomes follow from the definitions in `stats.rs`.

use crate::analysis::analyze;
use crate::stats::Stat;
use crate::testkit::Table;
use openriver_domain::Hand;

/// Outcome of `stat` for the player in `seat`.
fn outcome(hand: &Hand, seat: u8, stat: Stat) -> Option<bool> {
    let analysis = analyze(hand).unwrap();
    let player = analysis.player(seat).unwrap();
    stat.evaluate(&analysis, player)
}

fn six_max(stack: i64) -> Table {
    // Button seat 4; SB seat 5; BB seat 6; UTG seat 1; HJ seat 2; CO seat 3.
    Table::new(
        &[
            (1, stack),
            (2, stack),
            (3, stack),
            (4, stack),
            (5, stack),
            (6, stack),
        ],
        4,
        6,
        1,
        2,
    )
}

#[test]
fn walk_big_blind_is_dealt_in_but_not_voluntary() {
    let mut t = six_max(200);
    for seat in [1, 2, 3, 4, 5] {
        t.fold(seat);
    }
    let hand = t.finish_first_wins();
    // Everyone folds to the big blind: no decision, so no opportunity either way.
    assert_eq!(outcome(&hand, 6, Stat::Vpip), Some(false));
    assert_eq!(outcome(&hand, 6, Stat::Pfr), Some(false));
    assert_eq!(outcome(&hand, 6, Stat::RaiseFirstIn), None);
    assert_eq!(outcome(&hand, 6, Stat::SawFlop), Some(false));
    // The fold-around players had their open opportunity and passed.
    assert_eq!(outcome(&hand, 1, Stat::RaiseFirstIn), Some(false));
    assert_eq!(outcome(&hand, 1, Stat::Vpip), Some(false));
    // The winner of the walk nets the small blind; the small blind loses it.
    let analysis = analyze(&hand).unwrap();
    assert_eq!(analysis.player(6).unwrap().net, 1);
    assert_eq!(analysis.player(5).unwrap().net, -1);
}

#[test]
fn open_raise_then_fold_to_three_bet() {
    let mut t = six_max(200);
    t.fold(1).fold(2); // UTG, HJ fold
    t.raise_to(3, 6); // CO opens: steal attempt
    t.fold(4);
    t.fold(5);
    t.raise_to(6, 20); // BB 3-bets the steal
    t.fold(3); // CO folds to the 3-bet
    let hand = t.finish_first_wins();
    // CO
    assert_eq!(outcome(&hand, 3, Stat::RaiseFirstIn), Some(true));
    assert_eq!(outcome(&hand, 3, Stat::StealAttempt), Some(true));
    assert_eq!(outcome(&hand, 3, Stat::Pfr), Some(true));
    assert_eq!(outcome(&hand, 3, Stat::Vpip), Some(true));
    assert_eq!(outcome(&hand, 3, Stat::FoldToThreeBet), Some(true));
    assert_eq!(outcome(&hand, 3, Stat::ThreeBet), None); // opened, never faced a lone raise
                                                         // UTG and HJ were first in but folded
    assert_eq!(outcome(&hand, 1, Stat::StealAttempt), None); // UTG is not a steal seat
    assert_eq!(outcome(&hand, 2, Stat::RaiseFirstIn), Some(false));
    // Button folded facing the open raise: a 3-bet opportunity passed, not a cold call.
    assert_eq!(outcome(&hand, 4, Stat::ThreeBet), Some(false));
    assert_eq!(outcome(&hand, 4, Stat::ColdCall), Some(false));
    assert_eq!(outcome(&hand, 4, Stat::RaiseFirstIn), None);
    // Small blind folded to the steal; big blind 3-bet it.
    assert_eq!(outcome(&hand, 5, Stat::FoldSmallBlindToSteal), Some(true));
    assert_eq!(outcome(&hand, 5, Stat::ColdCall), None); // blinds are never cold callers
    assert_eq!(outcome(&hand, 6, Stat::ThreeBet), Some(true));
    assert_eq!(outcome(&hand, 6, Stat::ThreeBetVsSteal), Some(true));
    assert_eq!(outcome(&hand, 6, Stat::FoldBigBlindToSteal), Some(false));
    assert_eq!(outcome(&hand, 6, Stat::Pfr), Some(true));
}

#[test]
fn limped_pot_isolation_raise_is_not_a_three_bet() {
    let mut t = six_max(200);
    t.call(1); // UTG limps (level 1 -> still 1)
    t.fold(2).fold(3).fold(4).fold(5);
    t.check(6);
    let hand = t.finish_first_wins();
    // UTG limped first in: open limp, voluntary but not a raise.
    assert_eq!(outcome(&hand, 1, Stat::OpenLimp), Some(true));
    assert_eq!(outcome(&hand, 1, Stat::RaiseFirstIn), Some(false));
    assert_eq!(outcome(&hand, 1, Stat::Vpip), Some(true));
    assert_eq!(outcome(&hand, 1, Stat::Pfr), Some(false));
    // HJ faced one limper: not first in, so no open-limp or RFI opportunity.
    assert_eq!(outcome(&hand, 2, Stat::OpenLimp), None);
    // The big blind checked its option: no VPIP.
    assert_eq!(outcome(&hand, 6, Stat::Vpip), Some(false));
}

#[test]
fn raise_over_a_limper_is_an_open_raise_for_the_next_player_to_face() {
    let mut t = six_max(200);
    t.call(1); // limp
    t.raise_to(2, 8); // isolation raise
    t.fold(3).fold(4).fold(5).fold(6);
    t.fold(1); // limper folds to the raise
    let hand = t.finish_first_wins();
    // The isolation raiser did not raise first in (a limper was already in).
    assert_eq!(outcome(&hand, 2, Stat::RaiseFirstIn), None);
    assert_eq!(outcome(&hand, 2, Stat::Pfr), Some(true));
    // The CO facing it has a 3-bet opportunity (one raise ahead), not a 4-bet.
    assert_eq!(outcome(&hand, 3, Stat::ThreeBet), Some(false));
    assert_eq!(outcome(&hand, 3, Stat::FourBet), None);
    // The limper faced the raise: a 3-bet spot for them as well.
    assert_eq!(outcome(&hand, 1, Stat::ThreeBet), Some(false));
}

#[test]
fn four_bet_and_fold_to_four_bet() {
    let mut t = six_max(500);
    t.raise_to(1, 6); // UTG opens
    t.raise_to(2, 20); // HJ 3-bets
    t.fold(3).fold(4).fold(5).fold(6);
    t.raise_to(1, 60); // UTG 4-bets
    t.fold(2); // HJ folds to the 4-bet
    let hand = t.finish_first_wins();
    assert_eq!(outcome(&hand, 1, Stat::FourBet), Some(true));
    assert_eq!(outcome(&hand, 1, Stat::FoldToThreeBet), Some(false)); // faced the 3-bet, did not fold
    assert_eq!(outcome(&hand, 2, Stat::ThreeBet), Some(true));
    assert_eq!(outcome(&hand, 2, Stat::FoldToFourBet), Some(true));
    assert_eq!(outcome(&hand, 2, Stat::FourBet), None);
    // CO to BB faced one raise (3-bet opportunity), not the 3-bet itself, since they acted first.
    assert_eq!(outcome(&hand, 3, Stat::FourBet), Some(false));
    assert_eq!(outcome(&hand, 3, Stat::ThreeBet), None);
}

#[test]
fn cold_call_and_blind_defence_against_a_steal() {
    let mut t = six_max(200);
    t.fold(1).fold(2);
    t.raise_to(3, 6); // CO steals
    t.call(4); // button cold calls
    t.call(5); // small blind calls: the steal now has a caller
    t.fold(6);
    let hand = t.finish_first_wins();
    assert_eq!(outcome(&hand, 4, Stat::ColdCall), Some(true));
    // The small blind faced the open raise after a cold call: not an uncalled steal.
    assert_eq!(outcome(&hand, 5, Stat::FoldSmallBlindToSteal), None);
    assert_eq!(outcome(&hand, 5, Stat::ThreeBetVsSteal), None);
    // The big blind likewise faced raise + two callers.
    assert_eq!(outcome(&hand, 6, Stat::FoldBigBlindToSteal), None);
}

#[test]
fn squeeze_over_cold_caller_is_a_three_bet() {
    let mut t = six_max(500);
    t.fold(1).fold(2);
    t.raise_to(3, 6);
    t.call(4);
    t.raise_to(5, 30); // small blind squeezes
    t.fold(6).fold(3).fold(4);
    let hand = t.finish_first_wins();
    assert_eq!(outcome(&hand, 5, Stat::ThreeBet), Some(true));
    // A squeeze is not a steal defence: the open already had a caller.
    assert_eq!(outcome(&hand, 5, Stat::ThreeBetVsSteal), None);
    assert_eq!(outcome(&hand, 3, Stat::FoldToThreeBet), Some(true));
    assert_eq!(outcome(&hand, 4, Stat::ColdCall), Some(true));
}

#[test]
fn flop_c_bet_fold_and_turn_barrel() {
    let mut t = six_max(500);
    t.fold(1).fold(2).fold(3);
    t.raise_to(4, 6); // button opens
    t.fold(5);
    t.call(6); // big blind calls
    t.next_street(); // flop; pot 12
    t.check(6);
    t.bet(4, 8); // c-bet
    t.call(6);
    t.next_street(); // turn
    t.check(6);
    t.bet(4, 20); // second barrel
    t.fold(6);
    let hand = t.finish_first_wins();
    assert_eq!(outcome(&hand, 4, Stat::CBetFlop), Some(true));
    assert_eq!(outcome(&hand, 4, Stat::CBetTurn), Some(true));
    assert_eq!(outcome(&hand, 6, Stat::FoldToCBetFlop), Some(false)); // called
    assert_eq!(outcome(&hand, 6, Stat::CheckRaiseFlop), Some(false)); // checked, then called
    assert_eq!(outcome(&hand, 6, Stat::SawFlop), Some(true));
    assert_eq!(outcome(&hand, 6, Stat::WentToShowdown), Some(false));
    assert_eq!(outcome(&hand, 4, Stat::WonWhenSawFlop), Some(true));
    assert_eq!(outcome(&hand, 6, Stat::WonWhenSawFlop), Some(false));
    // The button won the whole pot: the big blind lost 6 + 8 = 14 and the folded
    // small blind's chip is dead money, so the button nets 15.
    let analysis = analyze(&hand).unwrap();
    assert_eq!(analysis.player(6).unwrap().net, -14);
    assert_eq!(analysis.player(4).unwrap().net, 15);
}

#[test]
fn check_raise_and_checked_back_flop() {
    let mut t = six_max(500);
    t.fold(1).fold(2).fold(3);
    t.raise_to(4, 6);
    t.fold(5);
    t.call(6);
    t.next_street();
    t.check(6);
    t.bet(4, 8);
    t.raise_to(6, 30); // check-raise
    t.fold(4);
    let hand = t.finish_first_wins();
    assert_eq!(outcome(&hand, 6, Stat::CheckRaiseFlop), Some(true));
    assert_eq!(outcome(&hand, 4, Stat::CBetFlop), Some(true));
    assert_eq!(outcome(&hand, 4, Stat::CBetTurn), None); // hand ended on the flop

    // Checked back: the aggressor had the option and passed.
    let mut t = six_max(500);
    t.fold(1).fold(2).fold(3);
    t.raise_to(4, 6);
    t.fold(5);
    t.call(6);
    t.next_street();
    t.check(6);
    t.check(4);
    let hand = t.finish_first_wins();
    assert_eq!(outcome(&hand, 4, Stat::CBetFlop), Some(false));
    assert_eq!(outcome(&hand, 4, Stat::CBetTurn), None); // no flop c-bet, no barrel
    assert_eq!(outcome(&hand, 6, Stat::CheckRaiseFlop), None); // never faced a bet
}

#[test]
fn fold_to_flop_c_bet_requires_the_preflop_aggressor() {
    let mut t = six_max(500);
    t.fold(1).fold(2).fold(3);
    t.raise_to(4, 6);
    t.fold(5);
    t.call(6);
    t.next_street();
    t.bet(6, 8); // big blind donks: not a c-bet
    t.fold(4);
    let hand = t.finish_first_wins();
    assert_eq!(outcome(&hand, 4, Stat::FoldToCBetFlop), None);
    // The button never acted first on an unbet flop, so there was no c-bet opportunity.
    assert_eq!(outcome(&hand, 4, Stat::CBetFlop), None);

    let mut t = six_max(500);
    t.fold(1).fold(2).fold(3);
    t.raise_to(4, 6);
    t.fold(5);
    t.call(6);
    t.next_street();
    t.check(6);
    t.bet(4, 8);
    t.fold(6);
    let hand = t.finish_first_wins();
    assert_eq!(outcome(&hand, 6, Stat::FoldToCBetFlop), Some(true));
}

#[test]
fn all_in_cap_removes_opportunities_that_cannot_be_taken() {
    // The button has exactly the call amount: no raise is possible, so no 3-bet opportunity.
    let mut t = Table::new(&[(1, 200), (2, 6), (3, 200)], 3, 6, 1, 2);
    // Seat 3 is the button; seat 1 is SB, seat 2 is BB. Heads-up logic does not apply (3 players).
    t.raise_to(3, 6);
    t.call(1);
    t.call(2);
    let hand = t.finish_first_wins();
    // BB had 6 total (posted 2): facing 6 total, stack behind 4 and to_call 4 -> cannot raise.
    assert_eq!(outcome(&hand, 2, Stat::ThreeBet), None);
    assert_eq!(outcome(&hand, 1, Stat::ThreeBet), Some(false));
}

#[test]
fn showdown_and_split_pot_accounting() {
    let mut t = six_max(500);
    t.fold(1).fold(2).fold(3);
    t.raise_to(4, 6);
    t.fold(5);
    t.call(6);
    t.next_street();
    t.check(6);
    t.check(4);
    t.next_street();
    t.check(6);
    t.check(4);
    t.next_street();
    t.check(6);
    t.check(4);
    // Split the pot between the two players.
    let hand = t.finish(0, |_, pot| pot.eligible_seats.clone());
    let analysis = analyze(&hand).unwrap();
    assert!(analysis.went_to_showdown);
    for seat in [4, 6] {
        let p = analysis.player(seat).unwrap();
        assert!(p.went_to_showdown && p.saw_flop && p.saw_turn && p.saw_river);
        assert!(p.net == 0 || p.net == 1, "odd chip goes to one player");
        assert_eq!(outcome(&hand, seat, Stat::WentToShowdown), Some(true));
        assert_eq!(outcome(&hand, seat, Stat::WonAtShowdown), Some(true)); // a share counts
    }
    // 6 + 6 + the small blind's 1 = 13 splits 7/6: the two players net +1 between them.
    let split: i64 = [4, 6]
        .iter()
        .map(|s| analysis.player(*s).unwrap().net)
        .sum();
    assert_eq!(split, 1);
    // Folded players never showed down.
    assert_eq!(outcome(&hand, 1, Stat::WentToShowdown), None);
    assert_eq!(outcome(&hand, 5, Stat::WentToShowdown), None);
}

#[test]
fn rake_is_not_attributed_to_any_player() {
    let mut t = six_max(500);
    t.fold(1).fold(2).fold(3);
    t.raise_to(4, 6);
    t.fold(5);
    t.call(6);
    t.next_street();
    t.check(6);
    t.bet(4, 10);
    t.fold(6);
    let hand = t.finish(1, |_, pot| vec![pot.eligible_seats[0]]);
    let analysis = analyze(&hand).unwrap();
    let net: i64 = analysis.players.iter().map(|p| p.net).sum();
    // Net results sum to minus the rake: chips only leave through the rake.
    assert_eq!(net, -1);
}

#[test]
fn heads_up_button_acts_first_preflop_and_posts_the_small_blind() {
    let mut t = Table::new(&[(2, 100), (5, 100)], 2, 6, 1, 2);
    t.raise_to(2, 5); // button / small blind opens
    t.fold(5);
    let hand = t.finish_first_wins();
    let analysis = analyze(&hand).unwrap();
    assert_eq!(
        analysis.player(2).unwrap().position,
        Some(crate::position::Position::Button)
    );
    assert_eq!(outcome(&hand, 2, Stat::RaiseFirstIn), Some(true));
    assert_eq!(outcome(&hand, 2, Stat::StealAttempt), Some(true));
    assert_eq!(outcome(&hand, 5, Stat::FoldBigBlindToSteal), Some(true));
}

#[test]
fn ante_does_not_count_as_voluntary_or_as_a_blind() {
    let mut t = Table::with_ante(&[(1, 100), (2, 100), (3, 100)], 3, 6, 1, 2, 1);
    t.fold(3);
    t.fold(1);
    let hand = t.finish_first_wins();
    let analysis = analyze(&hand).unwrap();
    // Everyone anted; only seats 1 (SB) and 2 (BB) posted blinds.
    assert!(!analysis.player(3).unwrap().posted_blind);
    assert!(analysis.player(1).unwrap().posted_blind);
    assert_eq!(outcome(&hand, 3, Stat::Vpip), Some(false));
    assert_eq!(analysis.player(3).unwrap().net, -1); // lost the ante only
}

/// Every accepted fixture hand flows parser -> engine with conserved chips.
#[test]
fn all_parser_fixtures_analyze_and_reconcile() {
    let dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/hands");
    let mut analyzed = 0;
    for entry in std::fs::read_dir(dir).unwrap() {
        let path = entry.unwrap().path();
        if path.extension().is_none_or(|ext| ext != "txt") {
            continue;
        }
        let Ok(parsed) = openriver_parser::parse(&std::fs::read(&path).unwrap()) else {
            continue; // intentionally unsupported inputs
        };
        for hand in &parsed.hands {
            let a = analyze(hand).unwrap_or_else(|e| panic!("{path:?}: {e}"));
            assert_eq!(a.players.iter().map(|p| p.net).sum::<i64>(), -hand.rake.0);
            analyzed += 1;
        }
    }
    assert!(
        analyzed >= 9,
        "expected the accepted fixtures, saw {analyzed}"
    );
}

/// The audited golden side-pot hand: Cy shoves, Ada and Bo call all-in.
#[test]
fn golden_side_pot_fixture_results() {
    let parsed = openriver_parser::parse(include_bytes!(
        "../../../fixtures/hands/golden_side_pot.txt"
    ))
    .unwrap();
    let a = analyze(&parsed.hands[0]).unwrap();
    // Contributions 100 / 200 / 200 after the 100 returned to Cy; awards 300 and 200.
    let by_name = |name: &str| a.players.iter().find(|p| p.name == name).unwrap();
    assert_eq!((by_name("Ada").invested, by_name("Ada").net), (100, 200));
    assert_eq!((by_name("Bo").invested, by_name("Bo").net), (200, 0));
    assert_eq!((by_name("Cy").invested, by_name("Cy").net), (200, -200));
    assert!(a.went_to_showdown);
    assert!(a.players.iter().all(|p| p.went_to_showdown));
    // Cy raised first in against two players who then called all-in.
    assert_eq!(a.preflop_aggressor, Some(3));
}
