# Foundation verification

Checked locally through 2026-10-23 on an Apple Silicon Mac.

| Check | Result | Scope |
| --- | --- | --- |
| `dart run melos run check` | Passed | Dart formatting/analysis, Flutter widget tests, Rust formatting/Clippy/tests. |
| `flutter_rust_bridge_codegen generate` | Passed | Regeneration matched the checked-in Dart, Rust, and C bridge outputs. |
| `flutter build macos --debug` | Passed | Packaged Flutter application with Rust core. |
| macOS native integration test | Passed | Dart → Rust call, SQLite migrate/reopen, typed invalid-path failure, and ready UI. |
| Normal macOS launch | Passed | The library-ready screen rendered and was visually inspected. |
| `flutter build ios --simulator` | Passed | Unsigned iOS simulator application; not a device run or store release. |
| `flutter build apk --debug` | Passed | Debug Android APK, including Rust builds for the configured Android ABIs. |
| Windows/Linux native builds | Pending | CI matrix is configured; each requires its own host runner. |
| iOS/Android device launch | Pending | Builds succeeded; on-device SQLite startup has not been exercised. |

An Android rebuild initially failed because two concurrent first-time Rust target installations conflicted. Reinstalling the pinned Rust 1.88.0 toolchain and its mobile targets resolved the local issue; the next APK build passed. Another initial iOS failure came from the [libc 0.2.190 regression](https://github.com/rust-lang/libc/issues/5601); the repository pins libc 0.2.189 for iOS and the simulator build passes. These are recorded in the [foundation ADR](adr/0001-foundation.md).

This verifies the application foundation and local database startup. It does not establish hand-history parser correctness, import performance, releases, or cross-device behavior.

## Parser coverage, 2026-10-24

`cargo test -p openriver_parser`, `cargo test --workspace`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo fmt --all -- --check`, and `git diff --check` passed after adding five out-of-order synthetic fixtures; the Rust parser suite has 19 passing tests. A regression test first showed that all five balanced hands were accepted. After the adapter change, it reports `InvalidHand` with the expected IDs, exact line spans, and parser version while accepting valid neighboring hands. The full Dart/Flutter check was not rerun for this parser-only change. This does not establish compatibility with a live export or native chooser behavior. The 50+ fixture target remains open with 25 `.txt` cases.

`dart run melos run check` passed after adding five rejected synthetic fixtures. The parser now rejects a hand where one player posts both blinds, even when its 6-cent pot balances. A mixed-file test confirms `IncompleteHand` for a missing summary, `InvalidHand` for a partial uncalled return and duplicate board card, and `UnsupportedFormat` for a EUR header; valid neighbors still import, and diagnostic IDs, line spans, and parser version are checked. The Rust parser suite has 18 passing tests and the fixture collection has 20 `.txt` cases. No packaged app or chooser test was rerun for this parser-only change.

`adb devices` listed no Android target on 2026-10-24, so the Android native import gate remains pending.

`dart run melos run check` passed after tightening canonical betting validation. Three new hand-audited synthetic fixtures reject a check while facing a bet, a short call with chips left, and a bet while facing a bet, despite balanced pots and awards. A mixed-file parser test accepts both valid neighbors and reports `InvalidHand` for each bad span; the existing short all-in call fixture still passes. The Rust parser suite has 17 passing tests. No packaged app or chooser test was rerun for this parser/domain-only change.

`dart run melos run check` passed after adding a contradictory-raise fixture. The parser now rejects hand 1016 because a raise from a 2-cent outstanding bet to 10 cents states a 7-cent increment instead of 8 cents, while accepting valid hands on either side. This check also exposed and corrected the stated increment in the raked-pot fixture without changing its contributions, pot, award, or rake. The Rust parser suite has 16 passing tests. No packaged app or chooser test was rerun for this parser-only change.

A further local `dart run melos run check` passed after adding three rejected synthetic fixtures for a missing hole-card marker, a small blind that contradicts the header despite balanced payouts, and a missing big blind. The adapter also rejects repeated hole-card markers or blind posts and antes posted after the hole-card marker. A mixed-file test confirms all three rejected spans leave valid neighbors accepted. The Rust parser suite now has 15 passing tests; `git diff --check` passed. The packaged macOS `flutter test integration_test/core_smoke_test.dart -d macos` also passed, including native import, reopen, repeat deduplication, and the 10,000-hand importing state. This is format-structure and core-path coverage, not live-export compatibility or native file-chooser proof.

`dart run melos run check` passed on the local Mac after adding three synthetic fixtures: a split 4-cent pot with two 2-cent awards, a 10-cent gross pot with a 9-cent award and 1-cent rake, and a showdown with mucked cards left unknown. Parser tests also confirm that a contradictory turn board yields `InvalidHand` for that span while valid neighboring hands remain accepted, and reject duplicate player names or conflicting card disclosures. This does not verify live room exports or mobile file selection.

A subsequent `dart run melos run check` passed after adding two more synthetic fixtures. The ante fixture reconciles a 6-cent pot and confirms that antes do not change preflop street contributions. The short all-in call fixture reconciles 12-cent main and side pots with different eligible seats. Parser tests reject inconsistent, missing, and repeated ante posts; a wrong payout; overlong lines; and more than 10,000 hands. An invalid hand's diagnostic leaves valid neighbors accepted. `git diff --check` also passed.

The packaged `flutter test integration_test/core_smoke_test.dart -d 2726114C-F577-4C2D-92B1-0B5746ECFFB9` passed on an iPhone 17 Pro simulator with iOS 26.0. It exercised native Dart → Rust → SQLite import, reopen/count, repeat deduplication, and the 10,000-hand importing UI state. It supplied a file path to the core; it did not operate the iOS file chooser. `adb devices` found no attached Android device or emulator, so Android import interaction remains untested. Windows/Linux CI results and live export compatibility are also still pending.

## Synthetic import slice, 2026-10-23

`dart run melos run check` passed after the import slice. Rust tests cover the golden side pot, a normal fold, mixed valid/truncated input, duplicate IDs/cards, same-file and overlapping-file deduplication, schema 1 upgrade without metadata loss, persistence after reopen, and rollback on an injected write failure. The packaged macOS integration test passed with a synthetic hand through Dart → Rust → SQLite, reopen/count, and repeat import. A second packaged run supplied 10,000 synthetic hands, observed the importing state, and finished with 10,001 stored hands including the earlier hand. macOS chooser interaction itself was not automated.

On an Apple Silicon Mac running macOS 26.6.2, a separate Rust debug test imported a 4,779,999-byte synthetic file containing 10,000 hands: parsing took 0.74 s, the first database write 1.16 s, and repeat import 1.04 s; row counts were 10,000 accepted and 10,000 duplicates on repeat. `/usr/bin/time -l` reported a 67,944,448-byte maximum resident set size for the test command. These are local measurements, not a device or release-build performance promise. iOS simulator and Android debug builds passed; mobile import interaction was not run. The [public room policy review](room-policy-review.md) is recorded, while a permitted real sample and format variant, Windows/Linux CI, and mobile device/simulator import checks remain pending.

## Canonical hand accounting, 2026-10-23

`cargo fmt --all`, `cargo test --workspace`, and `cargo clippy --workspace --all-targets -- -D warnings` passed after adding the canonical hand model. Domain tests cover the hand-audited side pot and uncalled return, duplicate known cards, invalid actions/stacks, ineligible awards, missing payouts, and unmatched contributions. The synthetic text fixture has not yet passed through a parser or SQLite, so these checks do not establish import behavior.
