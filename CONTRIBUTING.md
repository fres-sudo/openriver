# Contributing to OpenRiver

Start with the setup and commands in README.md. Keep dependencies and generated bindings reproducible; commit Cargo.lock and the root pubspec.lock with dependency changes.

## Ownership

- `apps/openriver`: presentation, navigation, composition, and Bloc/Cubit state.
- `packages/openriver_api`: a narrow typed API and platform build integration.
- Rust domain/parser/analytics: poker facts, invariants, normalization, and statistics.
- Rust storage: sole writer and migration owner for SQLite.
- Rust bridge: asynchronous application commands and typed failure mapping.

Do not duplicate poker rules or chip accounting in Dart. Do not expose arbitrary SQL through the bridge. Generated files are regenerated from Rust, not edited manually. Keep raw paths and personal hand data out of user-facing errors and logs.

## Checks

Run `dart run melos run check` before submitting changes. For native API or packaging changes, regenerate bindings and run `apps/openriver/integration_test/core_smoke_test.dart` on an installed native target. CI tests the other host operating systems.

Parser behavior changes require synthetic or explicitly redistributable fixtures and regression tests. Statistics need written opportunity/denominator definitions. Storage changes require new numbered migrations and reopen/migration tests; never edit an already released migration. A metadata-only schema exists today; importer and recovery behavior are future work.

Keep features suitable for post-session study. Add new packages when a functioning feature needs a distinct owner. Hosted commercial services belong in a separately managed private repository.
