#!/usr/bin/env bash
# Create the one signing key you will use for every future update of this app.
#
#   ./tools/make_keystore.sh
#
# Keep the .jks file and the passwords somewhere you will not lose them. If you
# lose this key you cannot ship an update under the same listing unless Play App
# Signing is enabled and you request an upload-key reset.
set -euo pipefail

ALIAS="${KEY_ALIAS:-bubbleshooter}"
OUT="${1:-classic_blast_release.jks}"

if [ -f "$OUT" ]; then
  echo "$OUT already exists - refusing to overwrite your signing key." >&2
  exit 1
fi

keytool -genkeypair -v \
  -keystore "$OUT" \
  -alias "$ALIAS" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Classic Blast, O=Classic Blast, C=IN"

echo
echo "Fingerprint (record this; Play Console shows it for upload certificates):"
keytool -list -v -keystore "$OUT" -alias "$ALIAS" | grep -E "SHA1:|SHA256:"

echo
echo "Add these to the repository secrets:"
echo "  ANDROID_KEYSTORE_BASE64   <- base64 -w0 $OUT"
echo "  ANDROID_KEYSTORE_PASSWORD"
echo "  ANDROID_KEY_ALIAS=$ALIAS"
echo "  ANDROID_KEY_PASSWORD"
