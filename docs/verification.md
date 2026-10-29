# Verification

## CI readiness, 2026-10-29

`dart run melos run check` passed on clean commit `cadb5de` before the CI trigger edit. It included Dart formatting and analysis, 10 Flutter widget tests, Rust formatting and Clippy, 21 parser tests, and the other Rust workspace tests. This is a local macOS result; it does not prove Windows or Linux builds.

GitHub reports `master` as this repository's default branch and Actions enabled. The workflow file on that branch listened for pushes to `main`; GitHub's Actions workflow listing was empty and `gh run list --workflow ci.yml` returned “workflow not found on the default branch.” The trigger now targets `master`. Commit `ceb8341` was pushed to `origin/master` and confirmed through the GitHub connector on 2026-10-29.

The GitHub connector's general read endpoint identified [push run 1](https://github.com/fres-sudo/openriver/actions/runs/40860842073) for `ceb8341`. Its Android job failed in `android-actions/setup-android@v3` before Flutter or the app build: the log says `Failed to find package 'tools'`. The [action's current documentation](https://github.com/android-actions/setup-android/blob/main/README.md) says v4 omits that removed package by default. The workflow has been changed to v4; the revised Android job has not run yet.

The Windows job reached `cargo test --workspace --locked` and failed `missing_or_repeated_ante_is_rejected`. That test's missing-ante mutation searched for an LF-terminated line, while Git checkout supplied a CRLF fixture, leaving the valid hand unchanged. The mutation now matches the ante wording without its line ending, and the test runs its cases with both LF and CRLF fixtures. Local `cargo test -p openriver_parser --locked` passed all 21 tests, and Rust formatting plus `git diff --check` passed. The revised test has not run on Windows yet.

The Linux job passed `cargo test --workspace --locked` but `flutter build linux` failed compiling Rive's bundled SheenBidi C source: `SBParagraph.c:618:16: error: unused variable 'stringLength' [-Werror,-Wunused-variable]`. The Rive plugin applies the app's standard `-Werror` flags after its own warning suppression. A targeted CMake option now suppresses this warning on `rive_common_plugin` only. No revised Linux build has run yet.

After the Android workflow and Windows parser-test edits, `dart run melos run check` passed locally on macOS, including formatting, analysis, Flutter tests, Clippy, and Rust workspace tests. This check preceded the Linux-only CMake option.

Run 1's `quality` job passed on Ubuntu, including the full check and generated-binding comparison. The iOS job passed its simulator build on macOS. Neither result exercises a mobile file chooser or native import interaction. The macOS packaged smoke test was still running when these results were recorded.

## Flutter design system, 2026-10-29

`dart run melos run check` passed on the working tree after the library screen moved to `shadcn_ui`: Dart formatting and analysis, 10 Flutter widget tests, Rust Clippy, and Rust workspace tests. The widget tests cover startup, retry, import reporting, system dark appearance, and layouts at 375×812, 812×375, and 1440×900 logical pixels with 2× text scaling. `flutter build macos --debug` produced a native app bundle, and `git diff --check` passed. A comparison with the published `shadcn_ui` 0.2.6 package found only the two documented runtime compatibility edits in the vendored copy. The app was not launched for this increment, so the updated screen has no new visual or native chooser interaction result.

## Foundation, 2026-10-23

Checked locally on an Apple Silicon Mac.

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

The packaged macOS `flutter test integration_test/core_smoke_test.dart -d macos` passed with two tests on the current working tree. The new mixed-file case sends one valid hand and one truncated hand through the real Dart → Rust parser → SQLite path, then checks the UI report (`imported 1`, `rejected 1`, `IncompleteHand` for hand 3002), one persisted hand after reopen, and one duplicate with the same rejection on repeat. `dart run melos run check` also passed: Dart formatting and analysis, 10 Flutter widget tests, Rust Clippy, and Rust workspace tests including 21 parser tests. These runs included separate uncommitted app and dependency changes. An attempt to run the new integration case on the iPhone simulator was rejected by automatic approval review after the user requested no simulator or running-app control, so this case has no new iOS result. The user reports that manual import works, without platform or test details recorded here.

`flutter build macos --debug` passed on the current working tree. In the resulting packaged macOS app, the native file chooser selected `fixtures/hands/normal_fold.txt`; the UI reported `Imported 1, duplicates 0, rejected 0` and `1 stored hands`. Selecting the same file through the chooser again reported `Imported 0, duplicates 1, rejected 0` with the stored count still at 1. This is direct chooser and Dart → Rust → SQLite → UI proof for a synthetic file. The build included separate uncommitted app changes, so it is not a clean committed-tree or release-build result. `adb devices` listed no Android target; Android chooser and import remain pending.

`dart run melos run check` passed on the local Mac after the 51-fixture coverage commit. It ran Dart formatting, analysis for both packages, 10 Flutter widget tests, Rust Clippy, and Rust workspace tests including all 21 parser tests. The run used the current working tree, which had separate uncommitted app and dependency changes, so it is not a clean committed-tree CI result. Packaged native import and chooser interaction were not rerun.

`cargo test -p openriver_parser`, `cargo test --workspace`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo fmt --all -- --check`, and `git diff --check` passed after adding 20 more synthetic fixtures. The Rust parser suite has 21 passing tests. Nineteen rejected cases cover header, seat, action, card, and summary contradictions; a mixed-file test verifies each stable diagnostic, ID, exact line span, and parser version while two valid neighboring hands remain accepted. A valid February 29, 2000 fixture verifies timestamp normalization and 4-cent pot accounting. The fixture collection has 51 `.txt` cases, meeting the numeric 50+ target for this synthetic adapter. The full Dart/Flutter check was not rerun while unrelated app changes were in progress. This does not establish live room compatibility.

`cargo test -p openriver_parser`, `cargo test --workspace`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo fmt --all -- --check`, and `git diff --check` passed after adding six timestamp fixtures. The new mixed-file test accepts the valid leap day as `2024-02-29T12:01:00Z`, rejects five impossible dates/times with `MalformedField`, checks exact source spans, and preserves valid neighbors. Direct assertions cover the 1900 and 2000 century leap-year cases. Before the parser change, the test showed all five impossible dates accepted. The collection now has 31 `.txt` fixtures and the parser suite has 20 passing tests. The full Dart/Flutter check was not rerun for this parser-only change.

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

## Import progress and cancellation, 2026-10-29

`dart run melos run check` passed locally on macOS with the FVM-pinned Flutter 3.41.2 and Rust 1.88.0: formatting, analysis, 11 Flutter widget tests, Clippy, and the Rust workspace tests (6 storage tests, 21 parser tests). New coverage: a storage test that cancels a 600-hand import after the second progress report and asserts no rows or batch remain and that a later import of the same hands succeeds, and a widget test for the progress text, Cancel button, and cancelled message. This is not a packaged-app or device run, and large-file cancellation latency has not been measured.

The ignored 10,000-hand storage test was rerun through the progress-reporting import path on macOS (Apple Silicon, Rust 1.88.0, `--release`, Rust core only, no UI): 4,779,999 source bytes, parse 68 ms, first write 203 ms, repeat import 77 ms, 10,000 rows then 10,000 duplicates. Progress is reported every 250 hands (41 reports). This is a Rust-level timing, not a packaged-app or mobile measurement, and memory was not measured.

## Statistics engine, 2026-10-29

`openriver_analytics` now holds a hand analyzer (per-decision bet level, amount to call, pot, live opponents), position derivation, 21 versioned statistic definitions ([stats-definitions.md](stats-definitions.md)), mergeable per-player aggregates with Wilson intervals, hand filters, and a `StatsEngine`. The canonical `Hand` gained `button_seat` (optional, defaulting to unknown for hands stored earlier); the synthetic adapter now requires a well-formed `is the button` clause and the parser suite grew to 22 tests.

`cargo fmt`, `cargo clippy --workspace --all-targets -D warnings` and `cargo test --workspace --locked` passed locally on macOS (Rust 1.88.0): 38 analytics tests (17 golden, 11 property of which 10 run 1,000 random hands each, 7 position and 3 unit), 22 parser, 6 storage. Five deliberate mutations of the engine were each caught. Property tests use a test-only simulator whose hands are validated by the real `validate_hand`; they show internal consistency and agreement with a naive oracle, not agreement with another tracker's numbers. The Dart side was not rebuilt for this change.
