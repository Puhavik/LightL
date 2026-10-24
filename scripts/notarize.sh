#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:?usage: notarize.sh <path-to-.app-or-.dmg>}"

if [ -z "${APPLE_API_KEY_BASE64:-}" ] || [ -z "${APPLE_API_KEY_ID:-}" ] || [ -z "${APPLE_API_ISSUER_ID:-}" ]; then
    echo "Notarization secrets missing; refusing to publish a non-notarized release." >&2
    exit 1
fi

WORK_DIR="${RUNNER_TEMP:-$(mktemp -d)}"
AUTH_KEY_PATH="${WORK_DIR}/AuthKey_${APPLE_API_KEY_ID}.p8"
echo "$APPLE_API_KEY_BASE64" | base64 --decode > "$AUTH_KEY_PATH"

SUBMIT_PATH="$TARGET"
case "$TARGET" in
    *.app)
        SUBMIT_PATH="${WORK_DIR}/$(basename "$TARGET").zip"
        ditto -c -k --keepParent "$TARGET" "$SUBMIT_PATH"
        ;;
esac

NOTARY_JSON="${WORK_DIR}/notary-$(basename "$TARGET").json"
xcrun notarytool submit "$SUBMIT_PATH" \
    --key "$AUTH_KEY_PATH" \
    --key-id "$APPLE_API_KEY_ID" \
    --issuer "$APPLE_API_ISSUER_ID" \
    --wait --output-format json | tee "$NOTARY_JSON"
python3 -c "import json,sys; sys.exit(0 if json.load(open(sys.argv[1])).get('status')=='Accepted' else 1)" "$NOTARY_JSON"

# The notary ticket can take a moment to propagate to CloudKit after "Accepted".
for attempt in 1 2 3 4 5; do
    if xcrun stapler staple "$TARGET" && xcrun stapler validate "$TARGET"; then
        exit 0
    fi
    echo "Stapling attempt ${attempt} failed, retrying in 30s..."
    sleep 30
done
echo "Stapling failed after retries." >&2
exit 1
