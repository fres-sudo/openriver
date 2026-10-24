# Next step: first trustworthy hand-history import

**Status:** In progress (synthetic import slice and local performance measurement complete; compatibility and platform gates pending) · **Updated:** 2026-10-24

**Target:** Finish the remaining import-related Milestone 0 proof, then deliver the first vertical slice of Milestone 1. This is an implementation guide, not a claim that importing already works.

## Outcome

A player selects a post-session NLHE cash hand-history text file. OpenRiver identifies one supported room format, validates each hand in Rust, stores valid hands in local SQLite, and shows an import report. A second import of the same file adds no duplicate hands. Malformed or uncertain hands appear in the report and are not silently stored as valid hands. No account or network connection is required.

The first adapter should be **PokerStars-like text exports**, using synthetic fixtures while format details and room policies are checked. Do not label the app as supporting live PokerStars exports until representative, lawfully usable samples and the applicable room terms have been reviewed. Keep any real samples out of the repository unless redistribution is permitted. Record the reviewed format variant, date, and policy decision before advertising compatibility.

This slice stops at import and a minimal stored-hand count or list needed to prove persistence. VPIP/PFR, graphs, replayer, AI coaching, cloud services, multi-room support, PLO, tournament rules, and live table assistance belong to later milestones.

## Working cadence

After each completed step or independently verified increment, update this guide and [`verification.md`](verification.md) with the result, then commit the related changes before starting the next increment. Use a Conventional Commit subject such as `feat(import): add hand-history parsing` or `fix(parser): reject conflicting blinds`. Keep the subject imperative and describe only changes included in that commit.

## Starting point

- [`apps/openriver`](../apps/openriver) already launches on macOS and has Android/iOS builds. Its Cubit handles library startup; no import route or file picker exists.
- [`packages/openriver_api`](../packages/openriver_api) exposes a typed startup facade. Bridge code is generated from Rust and checked in.
- [`openriver_domain`](../crates/openriver_domain/src/lib.rs) has cards, integer chips, streets, and action vocabulary. These are not yet a complete `Hand` or betting validator.
- [`openriver_parser`](../crates/openriver_parser/src/lib.rs) only rejects empty, oversized, or non-UTF-8 input. It has no format detector or hand parser.
- [`openriver_storage`](../crates/openriver_storage/src/lib.rs) owns SQLite, WAL, and migration 0001. The database only has library metadata. Add a new migration; do not rewrite 0001.
- [`openriver_bridge`](../crates/openriver_bridge/src/api/library.rs) currently opens/migrates/closes SQLite for startup. Import and query commands must own a coherent database lifecycle.
- [Foundation verification](verification.md) records what was actually tested. Windows/Linux packaging and mobile device startup still need host/device proof.

## Delivery sequence

### 1. Decide the canonical hand and parser contract

Define `GameDefinition`, `Hand`, `PlayerAtSeat`, `ActionEvent`, board/deal events, pots, awards, rake, uncalled returns, and provenance in `openriver_domain`. Use integer chip units and an explicit currency scale. Document that `RaiseTo` means the player's **total contribution on that street**. Represent unknown or mucked cards as unknown; never invent them.

The parser should return hands **and** diagnostics, including source hand identity or line span, severity, a stable code, and parser version. A detected but incomplete hand must be rejected or quarantined with a reason. Separate raw room wording from canonical events so future room adapters do not rewrite domain rules. Keep bounded input from `preflight`; add a bound on hand count/line length if the measured parser needs it.

**Proof:** synthetic fixtures cover a normal hand, one multi-way all-in with a side pot and uncalled return, a duplicate known card, and a truncated/malformed hand. Golden expected events and payouts are reviewed by hand. Tests check pot conservation, side-pot eligibility, nonnegative stacks, action order, and that a folded/all-in player cannot act again. Do not infer missing payouts to make a fixture pass.

### 2. Parse one format and preserve uncertainty

Implement a format detector and one room adapter in `openriver_parser`. Normalize blinds, antes when present, actions, street transitions, showdown, rake, and payouts. Split multi-hand files without letting one bad hand discard unrelated valid hands. Return `UnsupportedFormat` when detection is uncertain rather than guessing.

Start with synthetic PokerStars-like samples in [`fixtures/hands`](../fixtures/hands). Add edge and adversarial fixtures as the adapter grows: missing summary, all-in call smaller than the bet, side pots, uncalled return, split pot, cents precision, duplicate ID, unusual whitespace, non-UTF-8 bytes, and over-limit input. Record the expected parse result beside each fixture. The design's 50+ fixture target is the Milestone 1 coverage gate, not a reason to skip a working first slice.

**Proof:** fixture tests assert canonical values and precise diagnostics, including accepted/rejected counts. Fuzz or property tests can supplement golden cases but cannot replace them.

### 3. Persist through Rust only

Add migration `0002_...sql` with import batches, accepted hands, provenance, and a place to retain rejection diagnostics. Choose the query model deliberately: canonical serialized hand for lossless replay plus indexed columns needed for the first list/count. Scope uniqueness to a verified room/game/external-ID identity; define a hash fallback only for records without trustworthy IDs. A whole-file SHA-256 can dedupe batches, but hand-level uniqueness must also handle overlapping files. Store parser version and source hash without requiring raw history text in the database.

Use a transaction for the batch write, foreign keys, and explicit checks for values such as nonnegative chips. Treat migration failure and schema mismatch as typed errors. The existing `Library::open` creates a short-lived pool; decide whether import commands reopen it per request or share a library handle, then keep **one Rust owner** for writes and migrations. Do not add SQLite access to Dart.

**Proof:** a fresh database migrates, closes, and reopens; a database from schema 1 upgrades without data loss; importing the same file twice and importing overlapping files keep one row per hand; mixed valid/invalid input commits only valid hands and reports the rest. Test rollback on an injected write failure. Leave backup/export for a separate feature rather than copying a live WAL database.

### 4. Connect the use case to Flutter

Expose a coarse Rust command such as `import_hand_history(file_path)` that returns `ImportSummary` (`parsed`, `imported`, `duplicates`, `rejected`, diagnostics, parser version). Add a bounded query for a count or first page of hands so the UI can prove the data survived restart. Never expose SQL, unrestricted filesystem access, or raw Rust errors. Regenerate Flutter Rust Bridge bindings with the pinned generator and update the typed `OpenRiverCore` facade.

Add a visible import action to the shared Flutter app with a platform file chooser. Check the chooser's current desktop/mobile support before selecting a dependency. Show loading/progress, completion, unsupported-format and malformed-file states, and a retry path. The screen must say when hands were rejected and let the user inspect their reasons. Do not display raw file contents or paths in error messages or logs. Run work off the UI thread; if a 10,000-hand file takes long enough to need progress or cancellation, add a bridge progress mechanism before calling the spike complete.

**Proof:** a packaged macOS integration test selects or supplies a synthetic file, imports it through Dart → Rust, verifies the report and stored count, closes/reopens the library, and reimports without duplication. Widget tests cover loading, partial success, unsupported input, and retry. Run desktop CI on Windows and Linux; validate Android/iOS file permissions and native startup on devices or simulators before claiming import works there.

### 5. Complete the performance and compatibility gates

Generate 10,000 synthetic hands from the supported fixture shape and import them with a responsive UI, visible progress, and repeat-import behavior. Record elapsed time, memory, resulting row counts, and target device/OS. This is an acceptance measurement, not a hard-coded performance promise. Review the initial room's export format and usage policy, documenting the evidence and allowed user flow. The [technical design](POKER_PLATFORM_TECHNICAL_DESIGN.md) makes both of these Milestone 0 gates.

## Definition of done

The first import slice is complete when all of these are demonstrated:

1. A user-provided synthetic multi-hand file reaches Flutter → Rust parser → validator → SQLite → Flutter report on a packaged native target.
2. The reviewed golden hand's contributions, main/side pots, returns, rake, and awards reconcile exactly in integer units.
3. Invalid and incomplete hands produce stable, useful diagnostics and do not appear as accepted hands.
4. Same-file and overlapping-file reimports add no duplicate hands; reopening the database preserves accepted hands and provenance.
5. Format detection rejects unsupported input; the UI explains accepted, duplicate, and rejected counts without leaking private paths.
6. Migration from schema 1 succeeds, and failure tests prove transactional behavior.
7. `dart run melos run check`, binding regeneration, the packaged integration test, and the relevant platform builds pass. The 10,000-hand result and room-policy review are recorded before calling Milestone 0 finished.

## First implementation handoff

Begin with **step 1 and the golden side-pot fixture**. It sets the canonical accounting rules that parsing and storage must preserve. Then build steps 2–4 as one end-to-end path. Update this guide with any settled format or schema decision, and keep [`verification.md`](verification.md) tied to tests actually run.

### Decisions and progress, 2026-10-23

- The canonical model lives in `openriver_domain::hand`. Money uses signed 64-bit integer units with a game-level decimal scale. `RaiseTo` is total street contribution. Antes count toward the hand total but not the raise-to street amount. Unknown cards remain `None`.
- Canonical pots are gross and ordered by contribution tier. A return must equal the unmatched excess over the highest opposing street contribution. Awards name a pot and eligible seat. Validation checks stack bounds, action sequence and street order, inactive actors, duplicate known cards, pot tiers, award eligibility, and conservation. It never fills missing awards.
- [`golden_side_pot.txt`](../fixtures/hands/golden_side_pot.txt) and its [hand-audited expectation](../fixtures/hands/golden_side_pot.expected.md) specify a 300-unit main pot, 200-unit side pot, 100-unit return, and zero rake. The domain test builds those canonical facts directly; **the text fixture is not yet parsed**.
- The parser crate now defines a result and diagnostic contract with a stable code, severity, hand identity/span, and parser version. Detection and the adapter remain to be implemented. The next action is to parse the golden fixture plus a normal and malformed hand, passing accepted hands through `validate_hand` and reporting rejected spans.

### Import slice progress, 2026-10-23

- The strict `synthetic-stars-like` adapter parses the golden side-pot hand and a simple folded hand, validates canonical accounting, and reports malformed, incomplete, duplicate-ID, and invalid hands by ID/span. Detection only accepts the documented synthetic header. The parser is bounded to 32 MiB, 4,096 bytes per line, and 10,000 hands. This is **not** verified support for live PokerStars exports.
- Migration 0002 adds import batches, canonical serialized hands with indexed identity/date columns, provenance, and rejection diagnostics. Rust owns all SQLite writes. The `(room, game_variant, external_hand_id)` key deduplicates overlapping files; each batch is transactional. The bridge opens and closes the library per command.
- The shared Flutter app now selects a text file, calls Rust, and displays stored/imported/duplicate/rejected counts plus rejection reasons. The macOS build has read-only access to user-selected files. A packaged macOS integration test proves a synthetic import, persisted count after reopen, and duplicate handling on repeat.
- The 10,000-hand synthetic measurement passed on macOS with a visible importing state and repeat deduplication; details are in [verification.md](verification.md). No granular progress or cancellation mechanism has been added for this roughly three-second run.
- The [initial room policy review](room-policy-review.md) records a narrow post-session, own-history flow from public room pages; a permitted real export variant still needs review before any compatibility claim.
- Remaining before the definition of done: expand fixture coverage and room syntax, review a lawfully usable real sample, verify actual chooser behavior and native import on Android/iOS, and run Windows/Linux CI. These gates must be recorded before claiming broad import compatibility or Milestone 0 completion.

### Parser coverage, 2026-10-24

- Added hand-audited synthetic fixtures for a split pot, a raked pot, and mucked cards. The adapter preserves mucked cards as unknown. Turn and river lines now must repeat the exact board already seen; a contradiction rejects that hand while valid neighbors still import. Duplicate player names and conflicting card disclosures are rejected because either would make attribution uncertain.
- The full local `dart run melos run check` gate passed, including Flutter tests, Rust tests, analysis, formatting, and Clippy. The remaining fixture target is still 50+ distinct cases; live export syntax remains unverified. Next, obtain a lawfully usable sample or continue adding adversarial synthetic cases, then exercise the chooser and import on mobile targets and run Windows/Linux CI.
- Added synthetic ante and short all-in call fixtures with a hand-audited 6-cent pot and a 24-cent total across two 12-cent pots. The adapter now rejects differing, missing, or repeated ante posts rather than silently treating a partial ante as a valid hand. Tests also cover indented action lines, source line and hand-count limits, and isolation of invalid neighboring hands. The full local check and a packaged iPhone 17 Pro simulator import smoke test passed. These remain synthetic format checks; the 50+ fixture gate, actual chooser interaction, Android import, and Windows/Linux CI proof are still open.
- Added three rejected synthetic fixtures for a missing hole-card marker, a blind post contradicting the header, and a missing big blind. The adapter now requires one declared post of each blind before hole cards and rejects repeated markers, repeated blind posts, or a late ante. A mixed-file test proves valid neighbors survive these rejections. The full local check and packaged macOS import smoke test passed. Actual chooser interaction, Android import, Windows/Linux CI, a permitted live sample, and the 50+ fixture gate remain open.
- Added a rejected synthetic fixture for a stated raise increment that disagrees with its raise-to amount and the outstanding bet. The parser now verifies both numbers; a previously accepted raked-pot fixture was corrected from a 4-cent to a 3-cent stated raise while retaining its 5-cent total contribution. A mixed-file test confirms valid neighbors remain accepted. The full local check passed. The same platform, chooser, live-sample, and 50+ fixture gates remain open.
- Added three balanced but invalid synthetic betting cases: checking while facing a bet, calling short with chips left, and betting while facing a bet. Shared domain validation now rejects these action semantics; a short all-in call remains valid. A mixed-file test proves each bad hand is isolated from valid neighbors. The full local check passed. There are now 15 `.txt` fixtures; the remaining gates are to expand to 50+ distinct fixtures, review a lawfully usable export sample, exercise the native chooser and Android import, and run Windows/Linux CI.
- Added five more hand-audited rejected fixtures: one player posting both blinds, a missing summary, a partial uncalled return, a repeated board card, and an unsupported currency. The parser now requires distinct seats for the two blinds. A mixed-file test checks each stable diagnostic and line span while preserving valid neighboring hands. The full local check passed. There are now 20 `.txt` fixtures; the 50+ fixture target, lawfully usable export review, native chooser and Android import interaction, and Windows/Linux CI remain open.
- Added five balanced but out-of-order synthetic fixtures: a check or board card after collection, a check after showdown, a repeated showdown marker, and showdown after collection. The adapter now rejects these as `InvalidHand` while preserving valid neighboring hands. Rust formatting, workspace tests, and Clippy passed; the parser suite has 19 tests. There are now 25 `.txt` fixtures; the 50+ fixture target and external compatibility/platform gates remain open.
- Added a valid leap-day fixture and five impossible UTC dates. The adapter now validates the header's calendar date and time before storing its normalized timestamp, reporting `MalformedField` for bad dates while valid neighboring hands survive. Rust formatting, workspace tests, and Clippy passed; the parser suite has 20 tests and the fixture collection has 31 `.txt` cases. The 50+ fixture target and external compatibility/platform gates remain open.
- Added 19 distinct malformed/contradictory header, seat, action, card, and summary fixtures plus a valid century leap day. The mixed-file tests check accepted neighbors, stable diagnostic codes and IDs, exact source spans, parser version, normalized time, and balanced pots. Rust formatting, workspace tests, and Clippy passed. The collection has 51 `.txt` fixtures, meeting the numeric Milestone 1 fixture target for this synthetic format. A full local app check subsequently passed on the working tree with separately modified app files; a clean committed-tree check remains pending. The packaged macOS app's native chooser successfully imported the synthetic `normal_fold.txt` and reported one duplicate on repeat with one stored hand. The other gates are a lawfully usable live export variant and policy review, iOS/Android chooser and native import interaction, and Windows/Linux CI proof.
- Added a packaged native integration case for mixed valid and truncated input. On macOS it showed one imported hand, an `IncompleteHand` report for the rejected neighbor, one persisted hand after reopen, and a duplicate on repeat. The full local check passed. These runs included separate uncommitted app changes. Automatic approval review rejected a new iOS simulator test after the user requested no simulator or running-app control; no new iOS result is claimed. The user reports manual import works, but platform and selection details were not recorded. Live export compatibility, Android import, and Windows/Linux CI proof remain open.
