# External beta test protocol

Use this protocol only after a signed/notarized macOS beta archive and its SHA-256 file are available. The Milestone 2 exit criterion is **10 distinct external testers** completing import → analyze → replay without developer assistance. This document is test preparation; no tester result is currently recorded.

## Privacy and room-policy rules

- Test only with the tester's own lawfully obtained hand histories, or with the repository's synthetic fixtures.
- Never attach real hand histories, player names, database backups, API keys, signing credentials, or private paths to GitHub issues. Share only sanitized diagnostic codes and reproduction steps.
- Use OpenRiver after the session and close the poker-room client first. OpenRiver must not read live tables, scrape room software, provide real-time advice, or pool opponent data.
- A tester may keep the sample entirely local. Permission to use a history for testing does not imply permission to commit or redistribute it.

## Tester instructions

A coordinator may provide the archive, checksum, and these instructions, but must not demonstrate or perform the workflow during an exit-criterion session.

1. Confirm the archive checksum with `shasum -a 256 OpenRiver-VERSION+BUILD-macos.zip`, then unzip it normally.
2. Move **OpenRiver** to the desired location and open it normally. Do not bypass Gatekeeper or use a right-click override. Report any signing or notarization warning as a release blocker.
3. In **Library**, choose **Import hand history** and select a supported NLHE cash-history text file. Confirm that the completion report makes imported, duplicate, and rejected counts understandable.
4. Open **Statistics**. Select a player and room, apply a currency or UTC date filter, review the results and core statistics, and switch the cumulative graph between currency and big blinds.
5. Open **Hands**, find an imported hand, open its replay, and use the playback/step controls to inspect the hand.
6. In **Settings**, choose **Export library backup**, select a new filename, and confirm the success message. Keep the backup private.
7. Submit one [Beta feedback issue](https://github.com/fres-sudo/openriver/issues/new?template=beta-feedback.yml). Include the app version/build, macOS version, overall result, and sanitized reproduction details for any problem.

The expected result is that all steps can be completed from the product UI and these instructions, without a developer explaining the screens or repairing data. An unexpected result, unclear error, or request for help must be reported rather than silently counted as success.

## Coordinator evidence

For each session, record privately or in the release tracking issue:

- Anonymous tester ID, date, app version/build, macOS version, and feedback issue link.
- Whether import, analysis, replay, and backup were completed.
- Whether the tester needed any developer assistance.
- Blocking defects and their follow-up issue links.

Count a tester toward the exit criterion only after that person completes import → analyze → replay independently. Do not count the project owner, automated tests, demos, or a second session by the same tester as additional people. After 10 qualifying sessions, update `docs/verification.md` with the evidence references and `docs/NEXT_STEP.md` with the resulting milestone decision.
