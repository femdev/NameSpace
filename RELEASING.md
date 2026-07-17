# Releasing Namespace

Releases are produced entirely by CI. Pushing a version tag builds, Developer ID–signs,
notarizes, staples, and publishes a `.dmg` to a GitHub Release — no manual build steps.

## The tag drives the version

You do **not** edit any version numbers. `.github/workflows/release.yml` derives the app
version from the tag (`v0.2.0` → `0.2.0`) and passes it to the build, and
`CFBundleShortVersionString` is `$(MARKETING_VERSION)`, so the app, the GitHub Release, and
the `.dmg` filename all match the tag automatically. (The `MARKETING_VERSION` committed in
the project is just the local/dev default; the tag wins for releases.)

## Checklist

1. Make sure `main` is green in CI and contains everything you want to ship.
2. In `CHANGELOG.md`, move the items under `## [Unreleased]` to a new dated heading, e.g.
   `## [0.2.0] - 2026-07-17`, and add fresh `[Unreleased]` scaffolding. Commit + push.
3. Tag and push (use semantic versioning, `vMAJOR.MINOR.PATCH`):
   ```bash
   git tag v0.2.0
   git push origin v0.2.0
   ```
4. Watch the **Release** workflow in the repo's **Actions** tab. It takes ~1–5 minutes
   (notarization is the slow part).
5. When it's green, the notarized `Namespace-0.2.0.dmg` is attached to the new GitHub
   Release. Download it on a Mac (ideally a different one) and confirm it opens with **no
   Gatekeeper warning** — that's the end-to-end proof.

## If a release fails

Read the failing step in the Actions log, fix it, then re-trigger:

- Secrets are read at run time, so after fixing a **secret** you can just re-run:
  ```bash
  gh run rerun <run-id>
  ```
- After fixing **code or the workflow**, move the tag to the new commit:
  ```bash
  git push origin :refs/tags/v0.2.0   # delete remote tag
  git tag -d v0.2.0                    # delete local tag
  git tag v0.2.0                       # recreate at the fixed HEAD
  git push origin v0.2.0               # re-trigger
  ```

## One-time prerequisites (already set up)

- An **active paid Apple Developer Program** membership (required for Developer ID signing
  and notarization).
- These repository secrets (Settings → Secrets and variables → Actions), see
  [`docs/distribution-prd.md`](docs/distribution-prd.md):
  `DEVELOPER_ID_CERT_P12`, `DEVELOPER_ID_CERT_PASSWORD`, `SIGN_IDENTITY`,
  `AC_API_KEY_P8`, `AC_API_KEY_ID`, `AC_API_ISSUER_ID`.

## Notes

- Permission grants (Accessibility, Automation) **persist across upgrades** because the app
  is signed with a stable Developer ID identity keyed to the same team + bundle id. Users
  who replace the app with a newer notarized build do **not** have to re-grant.
- The app has no in-app auto-update; users download new releases from the Releases page.
