#!/usr/bin/env bash
set -euo pipefail

: "${MACOS_SIGNING_IDENTITY:?Set MACOS_SIGNING_IDENTITY to a Developer ID Application identity}"
: "${MACOS_NOTARY_PROFILE:?Set MACOS_NOTARY_PROFILE to a notarytool keychain profile}"
: "${MACOS_BETA_VERSION:?Set MACOS_BETA_VERSION, for example 0.1.0-beta.1}"
: "${MACOS_BUILD_NUMBER:?Set MACOS_BUILD_NUMBER to a unique positive integer}"

if [[ ! "$MACOS_BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  echo "MACOS_BUILD_NUMBER must be a positive integer" >&2
  exit 2
fi

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

for command in codesign ditto flutter shasum xcrun; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Required command is unavailable: $command" >&2
    exit 2
  fi
done

flutter pub get --enforce-lockfile
flutter build macos \
  --release \
  --build-name "$MACOS_BETA_VERSION" \
  --build-number "$MACOS_BUILD_NUMBER"

app_path="$root_dir/apps/openriver/build/macos/Build/Products/Release/OpenRiver.app"
entitlements_path="$root_dir/apps/openriver/macos/Runner/Release.entitlements"
if [[ ! -d "$app_path" ]]; then
  echo "Expected app bundle was not produced: $app_path" >&2
  exit 1
fi

while IFS= read -r -d '' nested_code; do
  codesign \
    --force \
    --sign "$MACOS_SIGNING_IDENTITY" \
    --options runtime \
    --timestamp \
    "$nested_code"
done < <(
  find "$app_path/Contents" \
    \( -name '*.app' -o -name '*.appex' -o -name '*.framework' -o -name '*.xpc' -o -name '*.dylib' \) \
    -depth \
    -print0
)

codesign \
  --force \
  --sign "$MACOS_SIGNING_IDENTITY" \
  --options runtime \
  --timestamp \
  --entitlements "$entitlements_path" \
  "$app_path"
codesign --verify --deep --strict --verbose=2 "$app_path"

output_dir="$root_dir/build/beta/macos"
archive_name="OpenRiver-${MACOS_BETA_VERSION}+${MACOS_BUILD_NUMBER}-macos.zip"
archive_path="$output_dir/$archive_name"
if [[ -e "$archive_path" ]]; then
  echo "Refusing to overwrite an existing beta archive: $archive_path" >&2
  exit 1
fi
mkdir -p "$output_dir"
temporary_dir="$(mktemp -d "$output_dir/notarization.XXXXXXXX")"
trap 'rm -rf "$temporary_dir"' EXIT
submission_archive="$temporary_dir/$archive_name"

ditto -c -k --keepParent "$app_path" "$submission_archive"
xcrun notarytool submit "$submission_archive" \
  --keychain-profile "$MACOS_NOTARY_PROFILE" \
  --wait
xcrun stapler staple "$app_path"
xcrun stapler validate "$app_path"
spctl --assess --type execute --verbose=2 "$app_path"

ditto -c -k --keepParent "$app_path" "$archive_path"
(
  cd "$output_dir"
  shasum -a 256 "$archive_name" > "$archive_name.sha256"
)

echo "Signed and notarized beta: $archive_path"
echo "SHA-256: $archive_path.sha256"
