# openriver_api

The app-facing Dart API and Flutter native build integration for OpenRiver. `OpenRiverCore` is injectable; `RustOpenRiverCore` loads generated bindings and calls Rust. Domain/persistence implementation lives in the root `crates/` workspace.

Build and regenerate from the monorepo root; see ../../README.md. This package is not independently publishable because its native build paths refer to sibling workspace crates. `cargokit/` is third-party vendored source with its original license; local modifications are recorded in docs/adr/0001-foundation.md.
