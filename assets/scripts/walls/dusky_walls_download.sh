#!/usr/bin/env bash
# Downloads dharmx/walls wallpaper collection via git clone (shallow)
# Source: https://github.com/dharmx/walls

set -euo pipefail

# --- Configuration -----------------------------------------------------------
readonly REPO_URL="https://github.com/dharmx/walls.git"
readonly TARGET_PARENT="${HOME:?HOME not set}/Pictures"
readonly WALLS_DIR="${TARGET_PARENT}/wallpapers/walls"

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
    fi
}
trap cleanup EXIT

# --- Dependency Verification -------------------------------------------------
check_deps() {
    local -a missing=()
    local dep
    for dep in git; do
        command -v "${dep}" &>/dev/null || missing+=("${dep}")
    done

    if (( ${#missing[@]} > 0 )); then
        log_error "Missing dependencies: ${missing[*]}"
        return 1
    fi
    return 0
}

# --- Size Report -------------------------------------------------------------
report_size() {
    if [[ -d "$WALLS_DIR" ]]; then
        local size
        size=$(du -sh "$WALLS_DIR" 2>/dev/null | cut -f1)
        log_info "Collection size: ${size}"
    fi
}

# --- Count Wallpapers --------------------------------------------------------
count_wallpapers() {
    local count=0
    if [[ -d "$WALLS_DIR" ]]; then
        count=$(find "$WALLS_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) 2>/dev/null | wc -l)
    fi
    echo "$count"
}

# --- List Categories ---------------------------------------------------------
list_categories() {
    if [[ -d "$WALLS_DIR" ]]; then
        local -a cats=()
        while IFS= read -r d; do
            [[ -d "$d" ]] && cats+=("$(basename "$d")")
        done < <(find "$WALLS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
        if (( ${#cats[@]} > 0 )); then
            log_info "Categories (${#cats[@]}): ${cats[*]}"
        fi
    fi
}

# --- Main Entry Point --------------------------------------------------------
main() {
    printf '%s:: dharmx/walls Wallpaper Installer%s\n' "${BOLD}" "${RST}"

    check_deps

    # Update existing clone
    if [[ -d "${WALLS_DIR}/.git" ]]; then
        printf '   Collection already installed at: %s\n' "${WALLS_DIR}"
        report_size

        local response
        if [[ -t 0 ]]; then
            read -r -p "   Update to latest? [y/N] > " response
        else
            log_error "Interactive terminal required."
            return 1
        fi

        case "${response,,}" in
            y|yes) ;;
            *)     log_info "Aborted by user."; return 0 ;;
        esac

        status_begin "Pulling latest changes"
        if git -C "$WALLS_DIR" pull --ff-only 2>/dev/null; then
            status_end 0
        else
            status_end 1
            log_warn "Fast-forward pull failed. Resetting to upstream..."
            status_begin "Resetting to origin/master"
            git -C "$WALLS_DIR" fetch origin
            git -C "$WALLS_DIR" reset --hard origin/master 2>/dev/null \
              || git -C "$WALLS_DIR" reset --hard origin/main
            status_end $?
        fi

        log_ok "Update complete."
        log_info "Wallpapers: $(count_wallpapers)"
        report_size
        return 0
    fi

    # Fresh install
    printf '   Download dharmx/walls wallpaper collection?\n'
    printf '   ~56 themed categories (abstract, anime, mountain, pixel, etc.)\n'
    printf '   Destination: %s\n' "${WALLS_DIR}"

    if [[ ! -t 0 ]]; then
        log_error "Interactive terminal required."
        return 1
    fi

    local response
    read -r -p "   [y/N] > " response
    case "${response,,}" in
        y|yes) ;;
        *)     log_info "Aborted by user."; return 0 ;;
    esac

    mkdir -p "$(dirname "$WALLS_DIR")"

    status_begin "Cloning dharmx/walls (shallow)"
    if ! git clone --depth 1 "$REPO_URL" "$WALLS_DIR"; then
        status_end 1
        log_error "Clone failed. Check your network connection."
        return 1
    fi
    status_end 0

    log_ok "Installation complete."
    log_info "Location: ${WALLS_DIR/#"${HOME}"/\~}"
    log_info "Wallpapers: $(count_wallpapers)"
    list_categories
    report_size
    return 0
}

main "$@"
