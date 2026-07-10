#!/usr/bin/env bash
# Sign, package, notarize, and staple a Namespace release .dmg.
#
# Usage:
#   scripts/package-release.sh <path-to-Namespace.app> [output-dir]
#
# Required env:
#   SIGN_IDENTITY   e.g. "Developer ID Application: Your Name (TEAMID)"
#
# Optional env (all three needed to notarize; otherwise the dmg is signed but NOT notarized):
#   AC_API_KEY_PATH   path to an App Store Connect API key .p8
#   AC_API_KEY_ID     the key's Key ID
#   AC_API_ISSUER_ID  the API issuer UUID
#
# Runs the same locally (cert already in your keychain) and in CI (workflow imports the
# cert into a temp keychain first).

set -euo pipefail

APP_PATH="${1:?usage: package-release.sh <path-to-Namespace.app> [output-dir]}"
OUT_DIR="${2:-dist}"
ENTITLEMENTS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/Namespace.entitlements"

: "${SIGN_IDENTITY:?set SIGN_IDENTITY to your Developer ID Application identity}"

[ -d "$APP_PATH" ] || { echo "error: no app bundle at $APP_PATH" >&2; exit 1; }
[ -f "$ENTITLEMENTS" ] || { echo "error: entitlements not found at $ENTITLEMENTS" >&2; exit 1; }

APP_NAME="$(basename "$APP_PATH" .app)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "0.0")"
mkdir -p "$OUT_DIR"
DMG="$OUT_DIR/$APP_NAME-$VERSION.dmg"

echo "==> Signing $APP_NAME.app with hardened runtime..."
# Single codesign is enough: the app embeds no third-party frameworks/dylibs.
codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$SIGN_IDENTITY" \
    "$APP_PATH"
codesign --verify --strict --verbose=2 "$APP_PATH"

echo "==> Building $DMG..."
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null

echo "==> Signing the .dmg..."
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"

if [ -n "${AC_API_KEY_PATH:-}" ] && [ -n "${AC_API_KEY_ID:-}" ] && [ -n "${AC_API_ISSUER_ID:-}" ]; then
    echo "==> Notarizing (this can take a few minutes)..."
    xcrun notarytool submit "$DMG" \
        --key "$AC_API_KEY_PATH" \
        --key-id "$AC_API_KEY_ID" \
        --issuer "$AC_API_ISSUER_ID" \
        --wait
    echo "==> Stapling the notarization ticket..."
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
    spctl --assess --type open --context context:primary-signature -v "$DMG" || true
    echo "OK: Notarized, stapled: $DMG"
else
    echo "WARNING: Notarization skipped (App Store Connect API key env not set)."
    echo "  Produced a SIGNED but NOT notarized dmg -- fine for a local dry run only:"
    echo "  $DMG"
fi

echo "$DMG"
