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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_XCCONFIG="$SCRIPT_DIR/Signing.local.xcconfig"

# Wire the identity into the build via a git-ignored local xcconfig. The committed
# Namespace.xcconfig has `#include? "Signing.local.xcconfig"`, so this file (when present)
# switches the app target from ad-hoc to the stable self-signed identity.
write_local_xcconfig() {
    echo "==> Writing $LOCAL_XCCONFIG..."
    cat > "$LOCAL_XCCONFIG" <<EOF
// Written by setup-signing.sh. Git-ignored, machine-local -- do NOT commit.
// Signs Namespace with a stable self-signed identity so every rebuild produces the same
// code signature, and macOS keeps your Accessibility / Automation grants across rebuilds.
CODE_SIGN_STYLE = Manual
CODE_SIGN_IDENTITY = $CERT_NAME
CODE_SIGNING_REQUIRED = YES
CODE_SIGNING_ALLOWED = YES
EOF
}

final_instructions() {
    echo
    echo "OK: Done -- the stable identity is now wired into the Xcode build."
    echo
    echo "One final reset so macOS re-issues the grants against the new signature:"
    echo "    ./reset-permissions.sh"
    echo "Then Cmd-R in Xcode and grant Accessibility + Automation once. On the first build"
    echo "macOS may ask to let codesign use the key -- click \"Always Allow\". After that,"
    echo "grants stick across rebuilds -- no more tccutil resets."
}

# Self-signed identities are reported as untrusted, so do NOT use `-v` (valid-only) here --
# that hides the cert and makes the script think it's missing (which also skipped writing
# the xcconfig). `find-identity -p codesigning` lists it; codesign can still sign with it.
if security find-identity -p codesigning | grep -q "\"$CERT_NAME\""; then
    echo "OK: Cert '$CERT_NAME' already in your login keychain -- skipping creation."
    write_local_xcconfig
    final_instructions
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS="$(uuidgen)"   # one-time password for the p12 transit only

echo "==> Generating 2048-bit RSA key + self-signed cert valid 10 years..."
openssl genrsa -out "$WORK/key.pem" 2048 2>/dev/null
openssl req -new -x509 -key "$WORK/key.pem" \
    -out "$WORK/cert.pem" -days 3650 \
    -subj "/CN=$CERT_NAME" \
    -addext "basicConstraints=critical,CA:FALSE" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null

echo "==> Bundling into PKCS#12 and importing into your login keychain..."
# The IMPORT (not the export) is where OpenSSL 3 bites: its default PKCS#12 MAC can't be
# verified by macOS `security` ("MAC verification failed during PKCS12 import"). The old
# code only fell back to -legacy if the *export* failed -- but the export succeeds, so the
# fallback never ran. Drive the fallback off the import instead. On LibreSSL (the system
# openssl) the modern format already imports fine.
import_signing_p12() {
    openssl pkcs12 -export $1 \
        -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
        -name "$CERT_NAME" -out "$WORK/cert.p12" \
        -password "pass:$PASS" 2>/dev/null || return 1
    security import "$WORK/cert.p12" \
        -k "$KEYCHAIN" -P "$PASS" \
        -T /usr/bin/codesign -T /usr/bin/security >/dev/null 2>&1
}

if ! import_signing_p12 ""; then
    echo "    (modern PKCS#12 rejected by macOS -- retrying with -legacy)"
    import_signing_p12 "-legacy" || {
        echo "ERROR: could not import the signing cert into the login keychain." >&2
        exit 1
    }
fi

echo "==> Setting partition list so codesign won't pop a password dialog every build..."
echo "    (You may be asked for your Mac login password once.)"
security set-key-partition-list \
    -S "apple-tool:,apple:,codesign:" \
    -s -k "" \
    "$KEYCHAIN" >/dev/null 2>&1 || {
    echo "    (Partition list set without the unlock -- that's fine, "
    echo "     codesign may prompt on first build but should remember.)"
}

echo
security find-identity -p codesigning | grep "$CERT_NAME" || {
    echo "ERROR: cert was imported but doesn't show up. Try again or check Keychain Access." >&2
    exit 1
}

write_local_xcconfig
final_instructions
