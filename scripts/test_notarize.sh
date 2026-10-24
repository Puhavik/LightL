#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin"
touch "$WORK/Fake.dmg"

write_xcrun() {
    local status="$1"
    cat > "$WORK/bin/xcrun" <<STUB
#!/usr/bin/env bash
case "\$1" in
    notarytool) echo '{"status": "$status"}' ;;
    stapler) exit 0 ;;
esac
STUB
    chmod +x "$WORK/bin/xcrun"
}

run_notarize() {
    env PATH="$WORK/bin:$PATH" RUNNER_TEMP="$WORK" "$@" "$SCRIPT_DIR/notarize.sh" "$WORK/Fake.dmg" > "$WORK/out.log" 2>&1
}

fail() {
    echo "FAIL: $1" >&2
    cat "$WORK/out.log" >&2 || true
    exit 1
}

write_xcrun Accepted

if run_notarize APPLE_API_KEY_BASE64= APPLE_API_KEY_ID= APPLE_API_ISSUER_ID=; then
    fail "missing secrets must fail"
fi
if ls "$WORK"/AuthKey_* >/dev/null 2>&1; then
    fail "no key file may be written when secrets are missing"
fi

KEY="$(printf 'fake-key' | base64)"
run_notarize APPLE_API_KEY_BASE64="$KEY" APPLE_API_KEY_ID=ABC123 APPLE_API_ISSUER_ID=issuer || fail "accepted submission must succeed"
if ls "$WORK"/AuthKey_* >/dev/null 2>&1; then
    fail "the private key must be removed after a successful run"
fi

write_xcrun Invalid
if run_notarize APPLE_API_KEY_BASE64="$KEY" APPLE_API_KEY_ID=ABC123 APPLE_API_ISSUER_ID=issuer; then
    fail "an invalid submission must fail"
fi
if ls "$WORK"/AuthKey_* >/dev/null 2>&1; then
    fail "the private key must be removed after a failed run"
fi

echo "notarize.sh tests passed"
