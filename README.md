# OpenRiver

Local-first poker study for **Windows, macOS, Linux, Android, and iOS**, using a shared Flutter application and a Rust core.

This repository includes a first synthetic hand-history import slice. The app opens a local SQLite library, selects a text file, validates supported synthetic NLHE hands in Rust, stores accepted hands, and reports duplicates and rejections. Live room compatibility, poker statistics, replay, coaching, and sync are not yet implemented.

## Quick start

Install **Flutter 3.41.2 / Dart 3.11** and **Rust via rustup**. Rust 1.88.0 is pinned in `rust-toolchain.toml`; `.fvmrc` records the Flutter version for optional FVM users. Install your platform's Flutter prerequisites and run `flutter doctor`.

From the repository root:

```sh
flutter pub get
dart run melos bootstrap
dart run melos run run:macos
```

For any other device:

```sh
cd apps/openriver
flutter devices
flutter run -d <device-id>
```

The native library is compiled and bundled automatically by Cargokit. No server, account, PostgreSQL, Docker, or running Rust service is needed. First builds download dependencies and Rust cross-compilation targets. Once dependencies are cached, the app itself works offline.

`./scripts/bootstrap.sh` (macOS/Linux) and `./scripts/bootstrap.ps1` (Windows) also prefetch the Rust dependencies.

## Workspace

```text
apps/openriver/                 Shared Flutter app; five native platform projects
packages/openriver_api/         Typed Dart facade, generated FFI, native packaging
crates/openriver_bridge/        Application commands exposed through flutter_rust_bridge
crates/openriver_domain/        Canonical cards, integer chip units, action vocabulary
crates/openriver_parser/        Bounded synthetic hand-history parser and diagnostics
crates/openriver_storage/       SQLx/SQLite owner, migrations, and import persistence
crates/openriver_analytics/     Validated opportunity counts and missing-sample semantics
contracts/                     Boundary for future public cloud contracts
fixtures/hands/                Synthetic parser fixtures and expected results
```

Dart uses **Pub Workspaces + Melos 8.2.1**. Workspace membership, shared resolution, and Melos scripts live in the root `pubspec.yaml`; there is deliberately no legacy `melos.yaml`. The repository has one Dart lockfile and one Cargo lockfile. Flutter state uses `flutter_bloc`/Cubit. Rust owns all database access and poker rules.

## Development commands

```sh
dart run melos run check             # format, analyze, Flutter tests, Clippy, Rust tests
dart run melos run format
dart run melos run rust:test
dart run melos run build:macos
dart run melos run build:windows
dart run melos run build:linux
dart run melos run build:android     # debug APK; development only
dart run melos run build:ios         # unsigned simulator build
```

Build each desktop target on its own OS. macOS/iOS require Xcode and CocoaPods; Android requires the Android SDK/NDK and Java 17; Linux requires Clang, CMake, Ninja, GTK 3 development files, and pkg-config; Windows requires Visual Studio's Desktop development with C++ workload. Cargokit installs Rust target libraries as needed.

To change the Rust API, install the exact generators, edit `crates/openriver_bridge/src/api`, and regenerate:

```sh
cargo install flutter_rust_bridge_codegen --version 2.12.0 --locked
cargo install cargo-expand --version 1.0.126 --locked
dart run melos run bridge:generate
cargo fmt --all
```

Generated bindings are checked in. Ordinary application builds do not need these generators. Keep the Rust bridge, Dart bridge, and generator on the same version.

Run the **real packaged native integration test** on a host/device (not the normal headless Flutter test runner):

```sh
cd apps/openriver
flutter test integration_test/core_smoke_test.dart -d macos
```

It opens and reopens a temporary SQLite database through Dart → Rust, verifies typed failure for an invalid path, and checks the ready screen. Unit/widget tests use a fake API and require no native library. CI defines desktop build and integration-test jobs plus Android and iOS simulator build jobs; configured jobs are not proof that all platforms have passed yet.

## Local data and scope

The app creates `openriver.sqlite3` in the OS application-support directory. Rust enables foreign keys, a bounded lock wait, WAL, and embedded migrations. Schema 2 stores import batches, validated hands, and rejection diagnostics. Do not copy a live SQLite file for backups; a consistent backup command is still future work.

The design document proposes a separate private cloud repository. This public product workspace intentionally contains no hosted AI/billing/auth service. Engine, study, AI-client, and sync packages will be introduced with their first functioning features rather than empty projects. Mobile targets are included now, ahead of the document's original mobile-later schedule.

Application identifiers currently use `dev.openriver.openriver` as a development placeholder. Set final identifiers and signing identities before distribution. Default Flutter icons remain placeholders. Android release signing, Apple signing/notarization, installers, and store deployment are not configured. The project source license remains undecided; do not publish a release until it is chosen. Third-party Cargokit retains its upstream license.

See the [next implementation step](docs/NEXT_STEP.md), [CONTRIBUTING.md](CONTRIBUTING.md), the [foundation decision](docs/adr/0001-foundation.md), and the original [technical design](docs/POKER_PLATFORM_TECHNICAL_DESIGN.md).
