# Security Policy

## Reporting a vulnerability

If you find a security issue in Namespace, please report it privately rather than
opening a public issue:

- Use GitHub's **[Report a vulnerability](../../security/advisories/new)** (Security →
  Advisories) to open a private advisory, **or**
- email the maintainer at **elondon@gmail.com** with details and, if possible, steps to
  reproduce.

Please give a reasonable window to respond and fix before any public disclosure. There is
no bug-bounty program — this is a small hobby project — but credit will gladly be given.

## Scope & threat model

A few things about Namespace that are relevant to its security posture:

- **Almost no network access.** The app's only network use is an **on-demand update
  check**: when you choose *Check for Updates…* from the menu, it makes a single request to
  GitHub's public Releases API to compare the latest release's version tag against the one
  you're running. It downloads and installs nothing automatically, and there is **no
  background traffic, no analytics, and no telemetry**. It collects no data and phones
  nothing home.
- **Local persistence only.** The only data stored is a Space-UUID → name dictionary in
  `UserDefaults` (`com.elise.Namespace`). Diagnostic logging is **off by default**; when
  enabled it writes to `~/Library/Logs/Namespace.log`, created with `0600` permissions
  and `O_NOFOLLOW` (won't follow a planted symlink).
- **Private Apple APIs.** The app calls undocumented CoreGraphics/SkyLight (CGS) symbols
  to enumerate Spaces (see `CGSPrivate.swift`). These are read-only queries. They are not
  a network or privilege boundary, but they are unsupported and could change across macOS
  releases.
- **Synthesized keystrokes.** Switching Spaces is done by asking System Events (via
  AppleScript) to send **fixed** Ctrl+N / Ctrl+Arrow key codes. No user-controlled data is
  ever interpolated into the AppleScript, so there is no script-injection surface. This is
  why the app requires **Accessibility** and **Automation** permissions.
- **Global hotkey.** A single Carbon `RegisterEventHotKey` (⌃⌥←) is registered; it invokes
  the in-app "Back" action only.

## Supported versions

This is a source-distributed, pre-1.0 project. Fixes are applied to the latest `main`.
There are no long-term support branches.
