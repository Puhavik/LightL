#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_NAME="LightL"
APP_BUNDLE="${PROJECT_DIR}/${APP_NAME}.app"
echo "==> Building ${APP_NAME} in Release mode..."
cd "${PROJECT_DIR}"
swift build -c release

# Determine build output directory
BUILD_DIR=""
if SWIFT_BIN_DIR="$(swift build -c release --show-bin-path 2>/dev/null)" && [ -d "${SWIFT_BIN_DIR}" ]; then
    BUILD_DIR="${SWIFT_BIN_DIR}"
elif [ -d "${PROJECT_DIR}/.build/release" ]; then
    BUILD_DIR="${PROJECT_DIR}/.build/release"
else
    FOUND_BIN=$(find "${PROJECT_DIR}/.build" -name "${APP_NAME}" -type f 2>/dev/null | grep -i release | head -n 1)
    if [ -n "$FOUND_BIN" ]; then
        BUILD_DIR="$(dirname "$FOUND_BIN")"
    else
        BUILD_DIR="${PROJECT_DIR}/.build/release"
    fi
fi

if [ ! -f "${BUILD_DIR}/${APP_NAME}" ]; then
    echo "Error: Binary ${APP_NAME} not found in ${BUILD_DIR}" >&2
    exit 1
fi

echo "==> Packaging into ${APP_NAME}.app..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
if [ -d "${PROJECT_DIR}/Sources/LightL/Resources" ]; then
    cp -R "${PROJECT_DIR}/Sources/LightL/Resources/." "${APP_BUNDLE}/Contents/Resources/"
fi

# Copy SPM resource bundle into Resources
RESOURCE_BUNDLE=""
if [ -d "${BUILD_DIR}/LightL_LightL.bundle" ]; then
    RESOURCE_BUNDLE="${BUILD_DIR}/LightL_LightL.bundle"
elif [ -d "${PROJECT_DIR}/.build/release/LightL_LightL.bundle" ]; then
    RESOURCE_BUNDLE="${PROJECT_DIR}/.build/release/LightL_LightL.bundle"
else
    RESOURCE_BUNDLE=$(find "${PROJECT_DIR}/.build" -name "LightL_LightL.bundle" 2>/dev/null | grep -i release | head -n 1)
fi

if [ -n "$RESOURCE_BUNDLE" ] && [ -d "$RESOURCE_BUNDLE" ]; then
    echo "==> Copying resource bundle: ${RESOURCE_BUNDLE} to ${APP_BUNDLE}/Contents/Resources/..."
    cp -R "${RESOURCE_BUNDLE}" "${APP_BUNDLE}/Contents/Resources/"
fi

GIT_TAG="$(git describe --tags --abbrev=0 2>/dev/null || echo 'v1.1.0')"
RAW_VERSION="${VERSION:-${GIT_TAG}}"
APP_VERSION="${RAW_VERSION#v}"

cat << EOF > "${APP_BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>ru</string>
    </array>
    <key>CFBundleExecutable</key>
    <string>LightL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.puhavik.LightL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>LightL</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Signing identity: SIGNING_IDENTITY env, else Developer ID Application, else Apple Development (local dev only).
# STRICT_SIGNING=1 (release): no ad-hoc fallback, any signing/verify failure aborts the build.
DEV_IDENTITY="${SIGNING_IDENTITY:-}"
if [ -z "$DEV_IDENTITY" ]; then
    DEV_IDENTITY=$(security find-identity -p codesigning -v 2>/dev/null | grep "Developer ID Application" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)
fi
if [ -z "$DEV_IDENTITY" ] && [ "${STRICT_SIGNING:-0}" != "1" ]; then
    DEV_IDENTITY=$(security find-identity -p codesigning -v 2>/dev/null | grep "Apple Development" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)
fi

KEYCHAIN_ARG=()
if [ -n "${KEYCHAIN_PATH:-}" ]; then
    KEYCHAIN_ARG=(--keychain "${KEYCHAIN_PATH}")
fi

ENTITLEMENTS_ARG=()
if [ -f "${PROJECT_DIR}/LightL.entitlements" ]; then
    ENTITLEMENTS_ARG=(--entitlements "${PROJECT_DIR}/LightL.entitlements")
fi

if [ "${STRICT_SIGNING:-0}" = "1" ] && { [ -z "$DEV_IDENTITY" ] || [ "$DEV_IDENTITY" = "-" ]; }; then
    echo "Error: STRICT_SIGNING=1 but no Developer ID signing identity available." >&2
    exit 1
fi

if [ -n "$DEV_IDENTITY" ] && [ "$DEV_IDENTITY" != "-" ]; then
    echo "==> Signing ${APP_NAME}.app with developer certificate: ${DEV_IDENTITY}..."
    if ! codesign --force --options runtime --timestamp "${KEYCHAIN_ARG[@]}" "${ENTITLEMENTS_ARG[@]}" --sign "${DEV_IDENTITY}" "${APP_BUNDLE}"; then
        if [ "${STRICT_SIGNING:-0}" = "1" ]; then
            echo "Error: signing failed and STRICT_SIGNING=1 forbids ad-hoc fallback." >&2
            exit 1
        fi
        echo "==> Signing failed (identity not found or expired), falling back to ad-hoc..."
        codesign --force --options runtime "${ENTITLEMENTS_ARG[@]}" --sign - "${APP_BUNDLE}"
    fi
else
    echo "==> Signing ${APP_NAME}.app (ad-hoc, local development only)..."
    codesign --force --options runtime "${ENTITLEMENTS_ARG[@]}" --sign - "${APP_BUNDLE}"
fi

codesign --verify --strict --verbose=2 "${APP_BUNDLE}"

echo "=========================================="
echo "✓ Сборка завершена успешно!"
echo "Приложение создано: ${APP_BUNDLE}"
echo "Для запуска выполните: open ${APP_BUNDLE}"
echo "=========================================="
