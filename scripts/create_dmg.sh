#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_NAME="LightL"
APP_BUNDLE="${PROJECT_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
DMG_PATH="${PROJECT_DIR}/${DMG_NAME}"

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "==> Building ${APP_NAME}.app first..."
    "${SCRIPT_DIR}/build_app.sh"
fi

echo "==> Creating ${DMG_NAME} with Applications symlink..."
DMG_TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "${DMG_TEMP_DIR}"' EXIT INT TERM

/usr/bin/ditto "${APP_BUNDLE}" "${DMG_TEMP_DIR}/${APP_NAME}.app"
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

rm -f "${DMG_PATH}"
hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_TEMP_DIR}" -ov -format UDZO "${DMG_PATH}"

DEV_IDENTITY="${SIGNING_IDENTITY:-}"
if [ -z "$DEV_IDENTITY" ]; then
    DEV_IDENTITY=$(security find-identity -p codesigning -v 2>/dev/null | grep "Developer ID Application" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)
fi
if [ -z "$DEV_IDENTITY" ]; then
    DEV_IDENTITY=$(security find-identity -p codesigning -v 2>/dev/null | grep "REDACTED" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)
fi
if [ -z "$DEV_IDENTITY" ]; then
    DEV_IDENTITY=$(security find-identity -p codesigning -v 2>/dev/null | grep "Apple Development" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)
fi

if [ -n "$DEV_IDENTITY" ] && [ "$DEV_IDENTITY" != "-" ]; then
    echo "==> Signing ${DMG_NAME} with ${DEV_IDENTITY}..."
    if ! codesign --force --timestamp --sign "${DEV_IDENTITY}" "${DMG_PATH}" 2>/dev/null; then
        echo "==> DMG signing with ${DEV_IDENTITY} failed, falling back to ad-hoc..."
        codesign --force --sign - "${DMG_PATH}" 2>/dev/null || true
    fi
else
    echo "==> No signing identity provided or found, skipping DMG signing."
fi

echo "=========================================="
echo "✓ DMG created: ${DMG_PATH}"
echo "=========================================="
