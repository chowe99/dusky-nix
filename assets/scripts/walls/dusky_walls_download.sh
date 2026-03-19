#!/usr/bin/env bash
# Downloads dharmx/walls wallpaper collection and installs to ~/Pictures/wallpapers/walls
# Source: https://github.com/dharmx/walls

set -euo pipefail

# --- Configuration -----------------------------------------------------------
readonly ZIP_URL="https://github.com/dharmx/walls/archive/refs/heads/master.zip"
readonly TARGET_PARENT="${HOME:?HOME not set}/Pictures"
readonly WALLS_DIR="${TARGET_PARENT}/wallpapers/walls"
readonly CACHE_DIR="${TARGET_PARENT}/.dharmx-walls-cache"
readonly CACHE_FILE="${CACHE_DIR}/dharmx-walls.zip"

# --- Terminal Setup (graceful degradation) -----------------------------------
if [[ -t 1 ]]; then
    readonly RST=$'\033[0m' BOLD=$'\033[1m'
    readonly RED=$'\033[31m' GRN=$'\033[32m' YEL=$'\033[33m' BLU=$'\033[34m'
    readonly CLR=$'\033[K'
    readonly IS_TTY=1
else
    readonly RST='' BOLD='' RED='' GRN='' YEL='' BLU='' CLR=''
    readonly IS_TTY=0
fi

# --- Logging -----------------------------------------------------------------
log_info()  { printf '%s[INFO]%s %s\n' "${BLU}" "${RST}" "$*"; }
log_ok()    { printf '%s[ OK ]%s %s\n' "${GRN}" "${RST}" "$*"; }
log_warn()  { printf '%s[WARN]%s %s\n' "${YEL}" "${RST}" "$*" >&2; }
log_error() { printf '%s[ERR ]%s %s\n' "${RED}" "${RST}" "$*" >&2; }

# --- Status Indicator --------------------------------------------------------
CURRENT_STATUS=""

status_begin() {
    CURRENT_STATUS="$1"
    if (( IS_TTY )); then
        printf '\r%s[....]%s %s%s' "${BLU}" "${RST}" "${CURRENT_STATUS}" "${CLR}"
    fi
}

status_end() {
    local -r rc=$1
    if (( IS_TTY )); then
        if (( rc == 0 )); then
            printf '\r%s[ OK ]%s %s%s\n' "${GRN}" "${RST}" "${CURRENT_STATUS}" "${CLR}"
        else
            printf '\r%s[FAIL]%s %s%s\n' "${RED}" "${RST}" "${CURRENT_STATUS}" "${CLR}"
        fi
    else
        if (( rc == 0 )); then
            log_ok "${CURRENT_STATUS}"
        else
            log_error "${CURRENT_STATUS}"
        fi
    fi
    CURRENT_STATUS=""
}

# --- Cleanup Trap ------------------------------------------------------------
cleanup() {
    local -r exit_code=$?
    if [[ -n "${CURRENT_STATUS}" ]]; then
        status_end 1
    fi
    if (( exit_code != 0 && exit_code != 130 )); then
        log_error "Script failed (exit ${exit_code})."
        if [[ -f "${CACHE_FILE}" ]]; then
            log_warn "Partial download preserved at: ${CACHE_FILE}"
        fi
    fi
}
trap cleanup EXIT

# --- Dependency Verification -------------------------------------------------
check_deps() {
    local -a missing=()
    local dep
    for dep in curl unzip; do
        command -v "${dep}" &>/dev/null || missing+=("${dep}")
    done

    if (( ${#missing[@]} > 0 )); then
        log_error "Missing dependencies: ${missing[*]}"
        return 1
    fi
    return 0
}

# --- Download ----------------------------------------------------------------
download_archive() {
    # Validate existing cache before re-downloading
    if [[ -f "${CACHE_FILE}" ]]; then
        status_begin "Verifying existing cache"
        if unzip -tq "${CACHE_FILE}" &>/dev/null; then
            status_end 0
            log_ok "Valid archive found. Skipping download."
            return 0
        fi
        status_end 1
        log_warn "Existing cache is invalid. Re-downloading..."
        rm -f -- "${CACHE_FILE}"
    fi

    log_info "Downloading dharmx/walls collection..."

    if ! curl -fL --retry 3 --retry-delay 5 --connect-timeout 30 \
              -o "${CACHE_FILE}" "${ZIP_URL}"; then
        log_error "Download failed."
        rm -f -- "${CACHE_FILE}"
        return 1
    fi
    log_ok "Download complete."

    # Verify integrity of the fresh download
    status_begin "Verifying download integrity"
    if ! unzip -tq "${CACHE_FILE}" &>/dev/null; then
        status_end 1
        log_error "Download corrupted. Please check your connection."
        rm -f -- "${CACHE_FILE}"
        return 1
    fi
    status_end 0
    return 0
}

# --- Archive Extraction ------------------------------------------------------
extract_archive() {
    status_begin "Extracting wallpapers"
    if ! unzip -qo "${CACHE_FILE}" -d "${CACHE_DIR}"; then
        status_end 1
        log_error "Extraction failed."
        return 1
    fi
    status_end 0
    return 0
}

# --- Locate Extracted Directory ----------------------------------------------
find_extracted_root() {
    local -a candidates=()

    shopt -s nullglob
    candidates=("${CACHE_DIR}"/walls-*/)
    shopt -u nullglob

    if (( ${#candidates[@]} == 0 )); then
        log_error "Extracted folder not found in ${CACHE_DIR}."
        return 1
    fi
    printf '%s' "${candidates[0]%/}"
}

# --- Install Wallpapers ------------------------------------------------------
install_wallpapers() {
    local -r src="$1"

    status_begin "Installing wallpapers"

    # Remove old installation if present
    if [[ -d "${WALLS_DIR}" ]]; then
        rm -rf -- "${WALLS_DIR}"
    fi

    # Move extracted contents into place
    mv -- "$src" "${WALLS_DIR}"
    status_end 0

    # Count and report
    local count=0
    count=$(find "${WALLS_DIR}" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) 2>/dev/null | wc -l)
    log_ok "Installed ${count} wallpapers"

    # List categories
    local -a cats=()
    while IFS= read -r d; do
        [[ -d "$d" ]] && cats+=("$(basename "$d")")
    done < <(find "${WALLS_DIR}" -mindepth 1 -maxdepth 1 -type d | sort)
    if (( ${#cats[@]} > 0 )); then
        log_info "Categories (${#cats[@]}): ${cats[*]}"
    fi

    return 0
}

# --- Main Entry Point --------------------------------------------------------
main() {
    printf '%s:: dharmx/walls Wallpaper Installer%s\n' "${BOLD}" "${RST}"

    if [[ ! -t 0 ]]; then
        log_error "Interactive terminal required."
        return 1
    fi

    # Check if already installed
    if [[ -d "${WALLS_DIR}" ]]; then
        local size
        size=$(du -sh "${WALLS_DIR}" 2>/dev/null | cut -f1)
        printf '   Collection already installed at: %s (%s)\n' "${WALLS_DIR}" "${size}"
        printf '   Re-download and replace?\n'
    else
        printf '   Download dharmx/walls wallpaper collection?\n'
        printf '   ~56 themed categories (abstract, anime, mountain, pixel, etc.)\n'
        printf '   Destination: %s\n' "${WALLS_DIR}"
    fi

    local response
    read -r -p "   [y/N] > " response
    case "${response,,}" in
        y|yes) ;;
        *)     log_info "Aborted by user."; return 0 ;;
    esac

    check_deps
    mkdir -p -- "${TARGET_PARENT}" "${WALLS_DIR%/*}" "${CACHE_DIR}"

    download_archive
    extract_archive

    local extracted_root
    extracted_root=$(find_extracted_root)
    install_wallpapers "${extracted_root}"

    rm -rf -- "${CACHE_DIR}"

    log_ok "Installation complete."
    log_info "Location: ${WALLS_DIR/#"${HOME}"/\~}"

    local size
    size=$(du -sh "${WALLS_DIR}" 2>/dev/null | cut -f1)
    log_info "Total size: ${size}"
    return 0
}

main "$@"
