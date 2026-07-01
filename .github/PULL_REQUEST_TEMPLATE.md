## What & why

<!-- What does this change do, and what problem does it solve? -->

## How was it tested?

<!-- Unit tests? Manual steps? Which macOS version? Note anything you couldn't test,
     e.g. behavior that depends on private APIs. -->

## Checklist

- [ ] Build succeeds (`xcodebuild build -scheme Namespace -destination 'platform=macOS'`)
- [ ] Tests pass (`xcodebuild test -scheme Namespace -destination 'platform=macOS'`)
- [ ] New pure logic has unit tests
- [ ] No new network calls, analytics, or third-party dependencies
- [ ] Updated the relevant `CLAUDE.md` / `README.md` if structure or behavior changed
- [ ] `CHANGELOG.md` updated under **[Unreleased]** if user-facing
