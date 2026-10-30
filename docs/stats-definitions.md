# Statistic definitions

Source of truth: [`crates/openriver_analytics/src/stats.rs`](../crates/openriver_analytics/src/stats.rs). Every statistic is an explicit **opportunity**: a rule for who is eligible (denominator) and who took it (numerator), evaluated per player per hand. A rate with no eligible hands is *no evidence*, never 0%. Rule changes bump the stat's version so stored aggregates can be recomputed.

## Conventions

- **Bet level** counts aggressive actions on a street. The big blind counts as the first preflop, so preflop level 1 is an unraised pot, 2 is facing an open raise, 3 facing a 3-bet, 4 facing a 4-bet. Postflop, 0 is unbet and 1 is facing a bet. A short all-in raise counts as a raise (as rooms report it).
- **Could raise** means the player has chips beyond the amount to call. Opportunities that need a raise (3-bet, 4-bet, blind 3-bet vs steal) require it.
- **Dealt in** means listed at the table with the hand. Sitting-out players are not modelled. A big blind who wins a walk is dealt in but has no decision, so VPIP and PFR record "not taken", while action-dependent stats record "not eligible".
- **Positions** come from the button seat plus the blinds actually posted. Heads-up, the button is the small blind. A dead button leaves no `Button`. Hands without a button seat (stored before it was recorded) keep all non-positional stats and report unknown positions. Early seats are named from the first to act (`UTG`, `UTG+1`...), the last three non-blind seats before the button are `Cutoff`, `Hijack`, `Lojack`, and a lone early seat is the `Cutoff`.
- **Steal**: a first-in raise (everyone before folded, only the blinds ahead) from the cutoff, button or small blind. A blind faces a steal only if nobody has called it since.
- **C-bet**: the last preflop raiser acts first on an unbet street and bets, with at least one opponent still able to respond. Facing a flop bet from that player is "facing a c-bet".
- **Net results** are chips collected minus chips invested (net of uncalled returns), per currency and decimal scale. Rake is not attributed to players, so a hand's player nets sum to minus the rake. Big-blind results are summed per hand as net / big blind.

## Statistics

| Key | Eligible (denominator) | Taken (numerator) |
|---|---|---|
| `vpip` | every hand dealt in | call, bet or raise preflop; blinds, antes and checks do not count |
| `pfr` | every hand dealt in | raised preflop |
| `rfi` | first to act voluntarily, facing only the blinds, could raise | raised |
| `open_limp` | same as `rfi` | called |
| `three_bet` | faced exactly one raise preflop, could raise | re-raised |
| `fold_to_three_bet` | raised at level 1, then their next decision faced exactly a 3-bet | folded |
| `four_bet` | faced exactly a 3-bet preflop, could raise | re-raised |
| `fold_to_four_bet` | 3-bet (raised at level 2), then faced exactly a 4-bet | folded |
| `cold_call` | first decision of the hand, facing a raise, not a blind | called |
| `steal` | `rfi` opportunity from cutoff, button or small blind | raised |
| `fold_sb_to_steal` / `fold_bb_to_steal` | that blind's first decision facing an uncalled steal | folded |
| `three_bet_vs_steal` | a blind facing an uncalled steal, could raise | re-raised |
| `saw_flop` | every hand dealt in | still in when the flop was dealt |
| `cbet_flop` | last preflop raiser, first to act on an unbet flop, opponent able to respond | bet |
| `fold_to_cbet_flop` | facing a flop bet from the last preflop raiser | folded |
| `cbet_turn` | made a flop c-bet, first to act on an unbet turn, opponent able to respond | bet |
| `check_raise_flop` | checked the flop, then faced a bet and could raise | raised |
| `wtsd` | saw the flop | reached showdown (two or more players left after all action) |
| `wsd` | reached showdown | collected a share of any pot (a split counts) |
| `wwsf` | saw the flop | collected a share of any pot |

Also tracked per player: postflop action counts (bets, raises, calls, checks, folds) giving aggression factor `(bets + raises) / calls` and aggression frequency `(bets + raises) / all postflop decisions` (both undefined, not zero, with no denominator), net winnings per currency, winnings at and away from showdown, and big blinds per 100 hands. Rates carry a Wilson 95% interval; the interval widens for small samples by construction.

## How it is tested

- Hand-scripted golden scenarios with outcomes audited by hand (`golden.rs`), plus the parser fixtures run end to end.
- Property tests over randomly played, validator-checked hands (`properties.rs`): chip conservation, decision well-formedness, position consistency, logical implications between stats (e.g. every raise statistic implies PFR, PFR implies VPIP), an independent naive oracle for VPIP, PFR, saw-flop, invested, collected and 3-bet, merge and ordering independence, JSON round trips, legacy hands without a button seat, and filter behaviour.
- A coverage test asserts the random hands actually reach flops, rivers, all-ins, side pots, 3-bets and 4-bets, returns and split pots.
- Mutation spot checks: deliberately breaking five definitions each made the suite fail.

## Hand evaluation and equity

[`evaluator.rs`](../crates/openriver_analytics/src/evaluator.rs) ranks the best five of five to seven cards as one comparable `HandRank` (suits never break ties; the wheel plays as five-high). [`equity.rs`](../crates/openriver_analytics/src/equity.rs) enumerates every runout for two to nine known hands and a board of zero, three, four or five cards. Shares are exact integers (a pot is 2,520 units, so any split of up to nine ways divides evenly); a deterministic seeded sampler exists for spots too large to enumerate and is never substituted silently.

Verification beyond examples:

- All 2,598,960 five-card hands produce the known category counts, and all 133,784,560 seven-card hands do too (the seven-card run is `#[ignore]`d; run it with `cargo test -p openriver_analytics --release -- --ignored`).
- An independent naive scorer, written a different way, is compared against the evaluator on every five-card hand: sorted by the naive score, the evaluator's ranks must be equal where it is equal and strictly increasing otherwise, and there must be exactly 7,462 distinct values.
- Seven-card ranks equal the best of all 21 five-card subsets on random hands.
- Equity: a hand-audited turn spot (7 wins in 44 runouts), chopped boards, conservation of the pot on every spot, invariance under player order and suit renaming, and bounds on aces against kings over all 1,712,304 preflop runouts.
