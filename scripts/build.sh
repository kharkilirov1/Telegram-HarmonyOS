#!/usr/bin/env bash
#
# build.sh - CI/CD build script for Telegram-HarmonyOS
#
# Usage:
#   ./scripts/build.sh [debug|release] [--clean]
#
# Environment:
#   OHOS_SDK  - (required) Path to the HarmonyOS SDK root directory
#   TDLIB_DIR - (optional) Path to pre-built TDLib for HarmonyOS
#
# Examples:
#   ./scripts/build.sh                # debug build
#   ./scripts/build.sh release        # release build (assembleApp)
#   ./scripts/build.sh debug --clean  # clean then debug build
#   ./scripts/build.sh --clean        # clean then debug build

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
EXPECTED_SDK_VERSION="6.0.2(22)"
HVIGORW="${PROJECT_ROOT}/hvigorw"

# ---------------------------------------------------------------------------
# Color helpers (disabled when not a terminal)
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi

info()  { printf "${CYAN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
ok()    { printf "${GREEN}[OK]${NC}    %s\n" "$*"; }

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
BUILD_MODE="debug"
CLEAN_BUILD=false

for arg in "$@"; do
    case "${arg}" in
        debug|release)
            BUILD_MODE="${arg}"
            ;;
        --clean)
            CLEAN_BUILD=true
            ;;
        -h|--help)
            sed -n '2,/^$/s/^# \?//p' "${BASH_SOURCE[0]}"
            exit 0
            ;;
        *)
            error "Unknown argument: ${arg}"
            error "Usage: $0 [debug|release] [--clean]"
            exit 1
            ;;
    esac
done

info "Build mode: ${BUILD_MODE}"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------

# 1. OHOS_SDK must be set and point to an existing directory
if [ -z "${OHOS_SDK:-}" ]; then
    error "OHOS_SDK environment variable is not set."
    error "Set it to the HarmonyOS SDK root, e.g.:"
    error "  export OHOS_SDK=/path/to/ohos-sdk"
    exit 2
fi

if [ ! -d "${OHOS_SDK}" ]; then
    error "OHOS_SDK path does not exist: ${OHOS_SDK}"
    exit 2
fi

info "OHOS_SDK: ${OHOS_SDK}"

# 2. Verify hvigorw is available
if [ -x "${HVIGORW}" ]; then
    HVIGOR_CMD="${HVIGORW}"
elif command -v hvigorw &>/dev/null; then
    HVIGOR_CMD="hvigorw"
elif [ -x "${PROJECT_ROOT}/node_modules/.bin/hvigor" ]; then
    HVIGOR_CMD="${PROJECT_ROOT}/node_modules/.bin/hvigor"
else
    error "hvigorw not found. Ensure it exists at the project root or is on PATH."
    error "You may need to run 'npm install' first to install @ohos/hvigor."
    exit 3
fi

info "Using hvigor: ${HVIGOR_CMD}"

# 3. Node.js check
if ! command -v node &>/dev/null; then
    error "Node.js is required but not found on PATH."
    exit 3
fi
info "Node.js version: $(node --version)"

# ---------------------------------------------------------------------------
# Clean previous build artifacts
# ---------------------------------------------------------------------------
clean_artifacts() {
    info "Cleaning previous build artifacts..."

    local dirs_to_clean=(
        "${PROJECT_ROOT}/build"
        "${PROJECT_ROOT}/entry/build"
        "${PROJECT_ROOT}/.hvigor"
        "${PROJECT_ROOT}/entry/.hvigor"
        "${PROJECT_ROOT}/oh_modules"
        "${PROJECT_ROOT}/entry/oh_modules"
    )

    for dir in "${dirs_to_clean[@]}"; do
        if [ -d "${dir}" ]; then
            rm -rf "${dir}"
            info "  Removed ${dir##"${PROJECT_ROOT}"/}"
        fi
    done

    ok "Clean complete."
}

if [ "${CLEAN_BUILD}" = true ]; then
    clean_artifacts
fi

# ---------------------------------------------------------------------------
# Install dependencies
# ---------------------------------------------------------------------------
info "Installing dependencies..."

# Install root-level hvigor dependencies
if [ -f "${PROJECT_ROOT}/oh-package.json5" ]; then
    if command -v ohpm &>/dev/null; then
        (cd "${PROJECT_ROOT}" && ohpm install)
    else
        warn "ohpm not found; falling back to npm install for hvigor toolchain."
        (cd "${PROJECT_ROOT}" && npm install --legacy-peer-deps 2>/dev/null || npm install)
    fi
fi

# Install entry module dependencies
if [ -f "${PROJECT_ROOT}/entry/oh-package.json5" ]; then
    if command -v ohpm &>/dev/null; then
        (cd "${PROJECT_ROOT}/entry" && ohpm install)
    else
        warn "ohpm not found; skipping entry module ohpm dependencies."
    fi
fi

ok "Dependencies installed."

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
BUILD_START="$(date +%s)"

cd "${PROJECT_ROOT}"

if [ "${BUILD_MODE}" = "release" ]; then
    info "Running assembleApp (release)..."
    "${HVIGOR_CMD}" assembleApp --mode release --no-daemon
    BUILD_TASK="assembleApp"
    OUTPUT_PATTERN="entry/build/default/outputs/**/*.app"
else
    info "Running assembleHap (debug)..."
    "${HVIGOR_CMD}" assembleHap --mode debug --no-daemon
    BUILD_TASK="assembleHap"
    OUTPUT_PATTERN="entry/build/default/outputs/**/*.hap"
fi

BUILD_EXIT=$?
BUILD_END="$(date +%s)"
BUILD_DURATION=$(( BUILD_END - BUILD_START ))

if [ ${BUILD_EXIT} -ne 0 ]; then
    error "Build failed (${BUILD_TASK}) with exit code ${BUILD_EXIT}."
    error "Duration: ${BUILD_DURATION}s"
    exit ${BUILD_EXIT}
fi

# ---------------------------------------------------------------------------
# Report results
# ---------------------------------------------------------------------------
ok "Build succeeded! (${BUILD_TASK}, ${BUILD_DURATION}s)"
info ""
info "Build mode:    ${BUILD_MODE}"
info "SDK version:   ${EXPECTED_SDK_VERSION}"
info "Duration:      ${BUILD_DURATION}s"
info ""

# Locate output artifacts
info "Output artifacts:"
FOUND_ARTIFACT=false
shopt -s globstar nullglob 2>/dev/null || true

SEARCH_DIR="${PROJECT_ROOT}/entry/build"
if [ "${BUILD_MODE}" = "release" ]; then
    SEARCH_EXT="app"
else
    SEARCH_EXT="hap"
fi

while IFS= read -r -d '' f; do
    info "  ${f}"
    FOUND_ARTIFACT=true
done < <(find "${SEARCH_DIR}" -name "*.${SEARCH_EXT}" -type f -print0 2>/dev/null)

if [ "${FOUND_ARTIFACT}" = false ]; then
    warn "No output artifacts found under entry/build/."
    warn "Expected pattern: ${OUTPUT_PATTERN}"
fi

info ""
ok "Done."
exit 0
