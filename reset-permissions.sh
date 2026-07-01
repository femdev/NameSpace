#!/usr/bin/env bash
# Run this after an Xcode rebuild has invalidated the Accessibility/Automation
# grants for Namespace. Clears the stale TCC entries and kills any running
# instance so the next ⌘R from Xcode triggers fresh permission prompts.
#
# Once we set up self-signed code signing, this script becomes unnecessary.

set -e

BUNDLE_ID="com.elise.Namespace"

echo "Resetting TCC grants for $BUNDLE_ID..."
tccutil reset Accessibility "$BUNDLE_ID"
tccutil reset AppleEvents   "$BUNDLE_ID"
tccutil reset PostEvent     "$BUNDLE_ID" 2>/dev/null || true

echo "Killing any running Namespace process..."
pkill -f Namespace.app || true

echo "Done. Now: ⌘R in Xcode, click a space, and click Allow on the prompts."
