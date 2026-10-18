#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get
cargo fetch --locked
dart run melos bootstrap
