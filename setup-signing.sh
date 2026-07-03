#!/usr/bin/env bash
# Creates a stable self-signed code-signing certificate for Namespace and
# imports it into your login keychain. Run once. After this, every Xcode rebuild
# will sign with the same identity, so macOS TCC keeps your Accessibility and
# Automation grants across rebuilds.
#
# Safe to re-run; will tell you if the cert already exists.

set -euo pipefail

CERT_NAME="Namespace Self-Signed"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning | grep -q "\"$CERT_NAME\""; then
    echo "✔ Cert '$CERT_NAME' already exists in your login keychain."
    security find-identity -v -p codesigning | grep "$CERT_NAME"
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS="$(uuidgen)"   # one-time password for the p12 transit only

echo "==> Generating 2048-bit RSA key + self-signed cert valid 10 years…"
openssl genrsa -out "$WORK/key.pem" 2048 2>/dev/null
openssl req -new -x509 -key "$WORK/key.pem" \
    -out "$WORK/cert.pem" -days 3650 \
    -subj "/CN=$CERT_NAME" \
    -addext "basicConstraints=critical,CA:FALSE" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null

echo "==> Bundling into PKCS#12 for keychain import…"
# Try modern format first, fall back to -legacy for OpenSSL 3 compat with macOS Security.
if ! openssl pkcs12 -export \
        -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
        -name "$CERT_NAME" \
        -out "$WORK/cert.p12" \
        -password "pass:$PASS" 2>/dev/null; then
    openssl pkcs12 -export -legacy \
        -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
        -name "$CERT_NAME" \
        -out "$WORK/cert.p12" \
        -password "pass:$PASS"
fi

echo "==> Importing into login keychain (codesign + security allowed to use it)…"
security import "$WORK/cert.p12" \
    -k "$KEYCHAIN" \
    -P "$PASS" \
    -T /usr/bin/codesign \
    -T /usr/bin/security \
    >/dev/null

echo "==> Setting partition list so codesign won't pop a password dialog every build…"
echo "    (You may be asked for your Mac login password once.)"
security set-key-partition-list \
    -S "apple-tool:,apple:,codesign:" \
    -s -k "" \
    "$KEYCHAIN" >/dev/null 2>&1 || {
    echo "    (Partition list set without the unlock — that's fine, "
    echo "     codesign may prompt on first build but should remember.)"
}

echo
security find-identity -v -p codesigning | grep "$CERT_NAME" || {
    echo "ERROR: cert was imported but doesn't show up. Try again or check Keychain Access."
    exit 1
}

# Wire the identity into the build via a git-ignored local xcconfig. The committed
# Namespace.xcconfig has `#include? "Signing.local.xcconfig"`, so this file (when present)
# switches the app target from ad-hoc to the stable self-signed identity above.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_XCCONFIG="$SCRIPT_DIR/Signing.local.xcconfig"
echo "==> Writing $LOCAL_XCCONFIG…"
cat > "$LOCAL_XCCONFIG" <<EOF
// Written by setup-signing.sh. Git-ignored, machine-local — do NOT commit.
// Signs Namespace with a stable self-signed identity so every rebuild produces the same
// code signature, and macOS keeps your Accessibility / Automation grants across rebuilds.
CODE_SIGN_STYLE = Manual
CODE_SIGN_IDENTITY = $CERT_NAME
CODE_SIGNING_REQUIRED = YES
CODE_SIGNING_ALLOWED = YES
EOF

echo
echo "✔ Done — the stable identity is now wired into the Xcode build."
echo
echo "One final reset so macOS re-issues the grants against the new signature:"
echo "    ./reset-permissions.sh"
echo "Then ⌘R in Xcode and grant Accessibility + Automation once. After that they stick"
echo "across rebuilds — no more tccutil resets."
