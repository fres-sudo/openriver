# macOS beta packaging

The primary Milestone 2 beta target is macOS. `scripts/package_macos_beta.sh` builds a release app, signs nested code and the app with a Developer ID Application identity and hardened runtime, submits the archive for Apple notarization, staples the ticket, verifies Gatekeeper assessment, and writes a versioned ZIP plus SHA-256 file under `build/beta/macos/`.

This is release configuration, not evidence that a signed beta exists. Producing the beta requires the project owner's Apple credentials. Before public distribution, the owner must also choose the source license, replace the development application identifier and placeholder icons, and confirm the intended release version.

## Local packaging

Prerequisites:

- A macOS machine with the normal OpenRiver build prerequisites.
- An Apple Developer Program membership and a **Developer ID Application** certificate/private key in the login keychain.
- An App Store Connect API key accepted for notarization.
- A notarytool keychain profile, created by the credential owner:

  ```sh
  xcrun notarytool store-credentials openriver-notary \
    --key /private/path/AuthKey_KEY_ID.p8 \
    --key-id KEY_ID \
    --issuer-id ISSUER_UUID
  ```

Run a normal check before packaging, then provide the release values explicitly:

```sh
dart run melos run check
MACOS_SIGNING_IDENTITY='Developer ID Application: Organization (TEAM_ID)' \
MACOS_NOTARY_PROFILE=openriver-notary \
MACOS_BETA_VERSION=0.1.0-beta.1 \
MACOS_BUILD_NUMBER=2 \
./scripts/package_macos_beta.sh
```

Use a new build number and archive name for every submission. The script refuses to overwrite an existing archive. Do not distribute the ordinary Flutter release build as a substitute: only an archive produced after successful signing, notarization, stapling, and Gatekeeper assessment is a beta candidate.

## GitHub Actions

The manually dispatched **macOS beta** workflow runs the full check and packages the app on `macos-14`. It uploads the ZIP and checksum as private-to-the-repository Actions artifacts; it does not create a public GitHub Release. Configure these repository secrets first:

- `MACOS_CERTIFICATE_BASE64`: base64-encoded Developer ID Application `.p12`, including the private key.
- `MACOS_CERTIFICATE_PASSWORD`: password for that `.p12`.
- `MACOS_SIGNING_IDENTITY`: exact identity name shown by `security find-identity -v -p codesigning`.
- `MACOS_NOTARY_KEY_BASE64`: base64-encoded App Store Connect `.p8` API key.
- `MACOS_NOTARY_KEY_ID`: the API key ID.
- `MACOS_NOTARY_ISSUER_ID`: the App Store Connect issuer UUID.

The workflow creates an ephemeral signing keychain and removes it at the end. Secrets must never be committed or included in tester feedback. A green workflow is packaging evidence; record the run URL, version, checksum, and verification result in `docs/verification.md` before calling the beta signed and notarized.
