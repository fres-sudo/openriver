# ADR 0001: OpenRiver application foundation

Date: 2026-10-16
Status: Accepted for initial implementation; platform viability remains under test.

## Decisions

- Name the product OpenRiver, the Dart app `openriver`, and packages/crates `openriver_*`.
- Use one Flutter app under `apps/openriver` for Windows, macOS, Linux, Android, and iOS. This applies the user's mobile requirement from day one.
- Use Dart Pub Workspaces with Melos 8 in root pubspec.yaml. Use a root Cargo workspace for the native core. Track both lockfiles.
- Pin Flutter 3.41.2, Rust 1.88.0, flutter_rust_bridge 2.12.0, and cargo-expand 1.0.126. These are a selected compatible baseline, not a claim to be the latest releases.
- Keep generated Dart/Rust bridge files checked in. Use the bridge's vendored Cargokit integration to compile/package native code during Flutter builds.
- Use SQLx 0.8.6 with SQLite and Tokio for the initial native persistence spike. SQLite is bundled through SQLx's SQLite dependency. Avoid an OS-installed database requirement.
- Use a single-connection pool, foreign keys, WAL, and a five-second busy timeout. Startup closes its pool explicitly. A long-lived application handle will be designed when import/query commands are added.
- Start with library metadata only, rather than freezing the illustrative hand schema prematurely. Readiness means a real migration and schema compatibility check succeeded.
- Keep the Dart facade injectable for tests, with no mock core selected in production.

## Package scope

Create domain, parser, storage, analytics, and bridge crates. The domain vocabulary and parser preflight are groundwork; they do not claim a complete poker model or supported import format. Engine, study, AI, sync, and cloud projects remain deferred until their first vertical feature. This follows the design's package-discipline guidance. The private cloud repository has not been created or published.

## Cargokit integration notes

Sources originate from `flutter_rust_bridge_codegen` 2.12.0's plugin template. Platform manifests point back to the root Cargo workspace. The build helper has small local patches:

1. `builder.dart` finds the nearest rust-toolchain.toml and uses its pinned channel. The upstream default used global stable, which could differ from command-line/CI builds.
2. `rustup.dart` recognizes versioned toolchain names in addition to stable/beta/nightly.
3. `build_pod.sh` no longer prints the whole process environment.

Reapply/review these patches on Cargokit upgrades. Cargo builds use `--locked`. Cargokit's independently resolved helper dependencies are vendored with their own lockfile and are not a Melos product package.

## Evidence and remaining gates

Record final local verification in `docs/verification.md`. The cross-platform CI matrix must pass on actual runners before promising Windows/Linux/mobile release support. Device lifecycle/WAL behavior, side-pot parsing, the 10k-hand import benchmark, backup/restore, and distribution signing remain separate work. This foundation does not complete Milestone 0 or the first public beta.

References: [Melos setup](https://melos.invertase.dev/getting-started), [flutter_rust_bridge integration](https://cjycode.com/flutter_rust_bridge/manual/integrate/builtin).

## iOS compatibility constraint

Native simulator compilation exposed the upstream [libc 0.2.190 iOS regression](https://github.com/rust-lang/libc/issues/5601): dyld declarations used by backtrace 0.3.76 were made macOS-only. The bridge constrains libc to 0.2.189 on iOS, and Cargo.lock records the compatible resolution. Remove this constraint only after the upstream fix is available and device/simulator builds pass. This is not a SQLx limitation.
