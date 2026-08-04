#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${DIST_DIR:-${ROOT_DIR}/dist}"
BUILD_DIR="${BUILD_DIR:-${ROOT_DIR}/.build/package}"
APP_VERSION="${APP_VERSION:-1.4.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(git -C "${ROOT_DIR}" log -1 --format=%ct 2>/dev/null || printf '946684800')}"
ARCHITECTURES="${ARCHITECTURES:-arm64 x86_64}"

case "${DIST_DIR}" in
    "${ROOT_DIR}/dist"|"${ROOT_DIR}/dist/"*) ;;
    *)
        printf 'Refusing to replace output outside %s/dist: %s\n' "${ROOT_DIR}" "${DIST_DIR}" >&2
        exit 2
        ;;
esac

for command_name in swift codesign lipo zip shasum plutil; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "${command_name}" >&2
        exit 1
    fi
done

if [[ ! "${APP_VERSION}" =~ ^[0-9]+([.][0-9]+){1,2}$ ]]; then
    printf 'APP_VERSION must be numeric, for example 1.4.0\n' >&2
    exit 2
fi
if [[ ! "${BUILD_NUMBER}" =~ ^[0-9]+$ ]]; then
    printf 'BUILD_NUMBER must be an integer\n' >&2
    exit 2
fi

rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}/apps"

printf 'Building release executables...\n'
read -r -a BUILD_ARCHITECTURES <<< "${ARCHITECTURES}"
BIN_DIRS=()
for architecture in "${BUILD_ARCHITECTURES[@]}"; do
    case "${architecture}" in
        arm64|x86_64) ;;
        *)
            printf 'Unsupported architecture: %s\n' "${architecture}" >&2
            exit 2
            ;;
    esac

    architecture_build_dir="${BUILD_DIR}-${architecture}"
    target_triple="${architecture}-apple-macosx13.0"
    printf 'Building %s...\n' "${target_triple}"
    swift build \
        --package-path "${ROOT_DIR}" \
        --scratch-path "${architecture_build_dir}" \
        --configuration release \
        --triple "${target_triple}" \
        --disable-sandbox
    BIN_DIRS+=("$(swift build \
        --package-path "${ROOT_DIR}" \
        --scratch-path "${architecture_build_dir}" \
        --configuration release \
        --triple "${target_triple}" \
        --show-bin-path)")
done

if [[ "${#BUILD_ARCHITECTURES[@]}" -eq 2 ]]; then
    ARCHITECTURE_LABEL="universal2"
else
    ARCHITECTURE_LABEL="${BUILD_ARCHITECTURES[0]}"
fi

APP_NAMES=(MAcordion MAcordionBreath MAcordionShisha)
BUNDLE_IDS=(
    com.satounatsuki.MAcordion
    com.satounatsuki.MAcordionBreath
    com.satounatsuki.MAcordionShisha
)

for index in "${!APP_NAMES[@]}"; do
    app_name="${APP_NAMES[index]}"
    bundle_id="${BUNDLE_IDS[index]}"
    app_path="${DIST_DIR}/apps/${app_name}.app"

    printf 'Assembling %s.app...\n' "${app_name}"
    mkdir -p "${app_path}/Contents/MacOS" "${app_path}/Contents/Resources"
    input_binaries=()
    for bin_dir in "${BIN_DIRS[@]}"; do
        input_binaries+=("${bin_dir}/${app_name}")
    done
    if [[ "${#input_binaries[@]}" -eq 1 ]]; then
        cp "${input_binaries[0]}" "${app_path}/Contents/MacOS/${app_name}"
    else
        lipo -create "${input_binaries[@]}" -output "${app_path}/Contents/MacOS/${app_name}"
    fi
    chmod 0755 "${app_path}/Contents/MacOS/${app_name}"
    cp -R "${ROOT_DIR}/AcOrDiOn/Resources/." "${app_path}/Contents/Resources/"

    cp "${ROOT_DIR}/Packaging/Info.plist" "${app_path}/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable ${app_name}" "${app_path}/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName ${app_name}" "${app_path}/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${bundle_id}" "${app_path}/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${APP_VERSION}" "${app_path}/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "${app_path}/Contents/Info.plist"

    codesign \
        --force \
        --sign "${SIGN_IDENTITY}" \
        --timestamp=none \
        --entitlements "${ROOT_DIR}/AcOrDiOn/MAcordion.entitlements" \
        "${app_path}"
    codesign --verify --deep --strict "${app_path}"
done

{
    printf 'source_commit=%s\n' "$(git -C "${ROOT_DIR}" rev-parse HEAD)"
    printf 'source_dirty=%s\n' "$(if git -C "${ROOT_DIR}" diff --quiet && git -C "${ROOT_DIR}" diff --cached --quiet; then printf no; else printf yes; fi)"
    printf 'source_date_epoch=%s\n' "${SOURCE_DATE_EPOCH}"
    printf 'app_version=%s\n' "${APP_VERSION}"
    printf 'build_number=%s\n' "${BUILD_NUMBER}"
    printf 'architectures=%s\n' "${ARCHITECTURES}"
    swift --version
    xcodebuild -version 2>/dev/null || true
} > "${DIST_DIR}/BUILD-INFO.txt"

cat > "${DIST_DIR}/apps/FIRST-LAUNCH.txt" <<'EOF'
MAcordion requires macOS 13 or later.

This reproducible local build is ad-hoc signed because no Developer ID
Application certificate is configured. On first launch:

1. Control-click MAcordion.app and choose Open.
2. Confirm Open in the dialog.
3. If macOS still blocks it, open System Settings > Privacy & Security and use
   Open Anyway for MAcordion.

The hinge version reads supported MacBook lid sensors through macOS IOHID.
No Python, pybooklid, Homebrew, or network connection is required.
EOF

# Normalized mtimes and sorted input make the ZIP containers repeatable when
# source, SDK/toolchain, architecture, signing identity, and inputs are equal.
normalized_timestamp="$(date -u -r "${SOURCE_DATE_EPOCH}" '+%Y%m%d%H%M.%S')"
find "${DIST_DIR}/apps" -exec touch -h -t "${normalized_timestamp}" {} +

for app_name in "${APP_NAMES[@]}"; do
    archive_path="${DIST_DIR}/${app_name}-${APP_VERSION}-${ARCHITECTURE_LABEL}.zip"
    (
        cd "${DIST_DIR}/apps"
        { find "${app_name}.app" -print; printf '%s\n' FIRST-LAUNCH.txt; } \
            | LC_ALL=C sort \
            | zip -X -y -q "${archive_path}" -@
    )
done

(
    cd "${DIST_DIR}"
    shasum -a 256 ./*.zip > SHA256SUMS
)

printf '\nPackages created in %s\n' "${DIST_DIR}"
cat "${DIST_DIR}/SHA256SUMS"
