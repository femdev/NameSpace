# PRD — Notarized release distribution

Status: in progress · Branch: `feature/notarized-releases` · Owner: Elise

## Problem

Namespace is source-distributed today: users clone and build it in Xcode. To hand people
a **ready-to-run download**, we need a signed, notarized `.dmg` that opens without
Gatekeeper warnings. The Mac App Store is not an option (see below), so the target is
**Developer ID + notarization** — the standard path for utility apps that live outside
the store.

### Why not the Mac App Store?

Namespace cannot ship on the MAS, and this is structural, not effort:
- **Private APIs.** It relies on undocumented CoreGraphics/SkyLight symbols
  (`CGSCopyManagedDisplaySpaces`, `CGSGetActiveSpace`, …). App Review auto-rejects private
  symbols, and there is no public API for enumerating/switching Spaces.
- **Mandatory App Sandbox.** MAS apps must be sandboxed, which forbids becoming an
  Accessibility-trusted process to synthesize system-wide keystrokes and driving System
  Events via Apple Events — exactly what Namespace does.

**Notarization is different from App Review:** it's an automated security/malware check.
It does **not** reject private-API usage, so a notarized Developer ID build is viable.

## Goals

- A tagged push (`vX.Y.Z`) produces a **notarized, stapled `.dmg`** attached to a GitHub
  Release, downloadable and runnable with no Gatekeeper prompts.
- The same signing/notarizing/packaging logic runs **locally** (one script) and in **CI**.
- Normal development (ad-hoc / self-signed) and the existing `ci.yml` are unaffected.

## Non-goals

- Mac App Store submission (impossible — see above).
- Sandboxing / entitlement minimization beyond what hardened runtime needs.
- Auto-update framework (Sparkle) — future work; noted below.

## Prerequisites (blocking)

- **Active paid Apple Developer Program membership (~$99/yr).** Required to create a
  *Developer ID Application* certificate and to use `notarytool`. A free or lapsed account
  cannot notarize. Everything here is built and ready, but cannot produce a real notarized
  artifact until the membership is active.
- A **Developer ID Application** certificate (created in the Apple Developer portal or via
  Xcode → Settings → Accounts → Manage Certificates).
- An **App Store Connect API key** (Keys tab) for headless notarization — avoids Apple ID
  2FA in CI.

## Approach

### Signing
- Hardened runtime (`--options runtime`) + secure timestamp, signed with the Developer ID
  Application identity.
- `Namespace.entitlements` grants `com.apple.security.automation.apple-events` so the app
  can drive System Events under hardened runtime. (No `disable-library-validation` needed:
  the only dynamically loaded code is Apple-signed system frameworks.)

### Packaging & notarization — `scripts/package-release.sh`
Given a built `Namespace.app`, the script:
1. `codesign` the app (hardened runtime, timestamp, entitlements).
2. Build a compressed `.dmg` (app + `/Applications` symlink).
3. Sign the `.dmg`.
4. `xcrun notarytool submit … --wait` (App Store Connect API key).
5. `xcrun stapler staple` the `.dmg`, and verify with `codesign`/`spctl`.

If notarization credentials are absent, it produces a **signed-but-not-notarized** dmg and
warns — useful for local dry runs.

### CI — `.github/workflows/release.yml`
On `push` of a tag matching `v*`:
1. Import the Developer ID cert (base64 secret) into a throwaway keychain.
2. Build Release unsigned (`CODE_SIGNING_ALLOWED=NO`).
3. Run `package-release.sh`.
4. Create a GitHub Release and upload the notarized `.dmg`.

### Required repo secrets

| Secret | What |
|---|---|
| `DEVELOPER_ID_CERT_P12` | base64 of the exported Developer ID Application cert (.p12) |
| `DEVELOPER_ID_CERT_PASSWORD` | password used when exporting the .p12 |
| `SIGN_IDENTITY` | e.g. `Developer ID Application: Your Name (TEAMID)` |
| `AC_API_KEY_P8` | base64 of the App Store Connect API key (.p8) |
| `AC_API_KEY_ID` | the key's Key ID |
| `AC_API_ISSUER_ID` | the API issuer UUID |

## Cutting a release

```bash
# once main has the release-ready state:
git tag v0.1.0
git push origin v0.1.0        # triggers release.yml → notarized .dmg on the Release
```

## Acceptance criteria

- [ ] `bash -n scripts/package-release.sh` and the workflow YAML are valid.
- [ ] Release configuration builds unsigned in CI.
- [ ] With secrets + paid account: tagging `vX.Y.Z` yields a notarized, stapled `.dmg`.
- [ ] `spctl -a -t open --context context:primary-signature Namespace.dmg` accepts it, and
      a fresh Mac opens the app with no Gatekeeper warning.
- [ ] `ci.yml` (build + test) stays green and untouched.

## Future work

- **Auto-updates** via Sparkle (appcast hosted on GitHub Releases).
- Prettier DMG (background image, icon layout).
- Universal binary check (already `SDKROOT=macosx`; confirm arm64 + x86_64 if desired).
