#!/usr/bin/env bash
# Downloads dharmx/walls wallpaper collection per-category via GitHub API
# Source: https://github.com/dharmx/walls
# The repo is ~3.8 GB — too large for a single zip/clone. This script
# downloads individual categories to keep each transfer small and reliable.

set -euo pipefail

# --- Configuration -----------------------------------------------------------
readonly REPO="dharmx/walls"
readonly BRANCH="main"
readonly TARGET_PARENT="${HOME:?HOME not set}/Pictures"
readonly WALLS_DIR="${TARGET_PARENT}/wallpapers/walls"
readonly API_BASE="https://api.github.com/repos/${REPO}"
readonly RAW_BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

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

# --- Dependency Verification -------------------------------------------------
check_deps() {
    local -a missing=()
    local dep
    for dep in curl jq; do
        command -v "${dep}" &>/dev/null || missing+=("${dep}")
    done

    if (( ${#missing[@]} > 0 )); then
        log_error "Missing dependencies: ${missing[*]}"
        return 1
    fi
    return 0
}

# --- Fetch category list from GitHub API -------------------------------------
fetch_categories() {
    local tree_json
    tree_json=$(curl -sf "${API_BASE}/git/trees/${BRANCH}" \
        -H "Accept: application/vnd.github+json") \
        || { log_error "Failed to fetch repo tree from GitHub API."; return 1; }

    # Extract directory names (exclude files like README, .gitignore, etc.)
    echo "$tree_json" | jq -r '.tree[] | select(.type == "tree") | .path' | sort
}

# --- Fetch file list for a category ------------------------------------------
fetch_category_files() {
    local category="$1"
    local tree_json
    tree_json=$(curl -sf "${API_BASE}/git/trees/${BRANCH}:${category}" \
        -H "Accept: application/vnd.github+json") \
        || { log_error "Failed to fetch file list for '${category}'."; return 1; }

    echo "$tree_json" | jq -r '.tree[] | select(.type == "blob") | .path'
}

# --- Download a single category ----------------------------------------------
download_category() {
    local category="$1"
    local dest="${WALLS_DIR}/${category}"
    local -i total=0 downloaded=0 skipped=0 failed=0

    mkdir -p "$dest"

    # Get file list
    local files
    files=$(fetch_category_files "$category") || return 1
    total=$(echo "$files" | wc -l)

    while IFS= read -r filename; do
        [[ -z "$filename" ]] && continue
        local filepath="${dest}/${filename}"

        # Skip if already downloaded
        if [[ -f "$filepath" ]]; then
            (( skipped++ ))
            continue
        fi

        # Download with encoded URL (spaces → %20)
        local encoded_category encoded_filename
        encoded_category=$(printf '%s' "$category" | sed 's/ /%20/g')
        encoded_filename=$(printf '%s' "$filename" | sed 's/ /%20/g')

        if curl -sfL --http1.1 --retry 2 --retry-delay 3 --connect-timeout 15 \
                -o "$filepath" "${RAW_BASE}/${encoded_category}/${encoded_filename}"; then
            (( downloaded++ ))
        else
            (( failed++ ))
            rm -f "$filepath"
        fi

        # Progress indicator
        if (( IS_TTY )); then
            local done_count=$((downloaded + skipped + failed))
            printf '\r   %s: %d/%d (new: %d, cached: %d, fail: %d)%s' \
                "$category" "$done_count" "$total" "$downloaded" "$skipped" "$failed" "${CLR}"
        fi
    done <<< "$files"

    if (( IS_TTY )); then
        printf '\r'
    fi

    if (( failed > 0 )); then
        log_warn "${category}: ${downloaded} downloaded, ${skipped} cached, ${failed} failed (${total} total)"
    else
        log_ok "${category}: ${downloaded} downloaded, ${skipped} cached (${total} total)"
    fi
}

# --- Main Entry Point --------------------------------------------------------
main() {
    printf '%s:: dharmx/walls Wallpaper Installer%s\n' "${BOLD}" "${RST}"
    printf '   Source: github.com/%s\n\n' "${REPO}"

    if [[ ! -t 0 ]]; then
        log_error "Interactive terminal required."
        return 1
    fi

    check_deps

    log_info "Fetching category list..."
    local categories_raw
    categories_raw=$(fetch_categories) || return 1

    local -a categories=()
    while IFS= read -r cat; do
        [[ -n "$cat" ]] && categories+=("$cat")
    done <<< "$categories_raw"

    if (( ${#categories[@]} == 0 )); then
        log_error "No categories found."
        return 1
    fi

    printf '   Found %d categories:\n' "${#categories[@]}"
    local -i i=1
    for cat in "${categories[@]}"; do
        # Mark already-downloaded categories
        local marker="  "
        [[ -d "${WALLS_DIR}/${cat}" ]] && marker="${GRN}*${RST} "
        printf '   %s%2d) %s\n' "$marker" "$i" "$cat"
        (( i++ ))
    done

    printf '\n   %s* = already downloaded%s\n' "${GRN}" "${RST}"
    printf '\n   Options:\n'
    printf '     a) Download ALL categories\n'
    printf '     1,3,5 or 1-10) Download specific categories\n'
    printf '     q) Quit\n\n'

    local response
    read -r -p "   > " response

    case "${response,,}" in
        q|quit|n|no|"")
            log_info "Aborted by user."
            return 0 ;;
    esac

    # Parse selection
    local -a selected=()

    if [[ "${response,,}" == "a" || "${response,,}" == "all" ]]; then
        selected=("${categories[@]}")
    else
        # Parse comma-separated values and ranges like "1,3,5-10,12"
        IFS=',' read -ra parts <<< "$response"
        for part in "${parts[@]}"; do
            part=$(echo "$part" | tr -d ' ')
            if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                local start="${BASH_REMATCH[1]}" end="${BASH_REMATCH[2]}"
                for (( j=start; j<=end; j++ )); do
                    if (( j >= 1 && j <= ${#categories[@]} )); then
                        selected+=("${categories[$((j-1))]}")
                    fi
                done
            elif [[ "$part" =~ ^[0-9]+$ ]]; then
                if (( part >= 1 && part <= ${#categories[@]} )); then
                    selected+=("${categories[$((part-1))]}")
                fi
            else
                log_warn "Ignoring invalid selection: $part"
            fi
        done
    fi

    if (( ${#selected[@]} == 0 )); then
        log_error "No valid categories selected."
        return 1
    fi

    printf '\n'
    log_info "Downloading ${#selected[@]} categories to ${WALLS_DIR/#"${HOME}"/\~}"
    mkdir -p "$WALLS_DIR"

    local -i cat_done=0
    for cat in "${selected[@]}"; do
        (( cat_done++ ))
        log_info "[${cat_done}/${#selected[@]}] ${cat}"
        download_category "$cat"
    done

    printf '\n'
    log_ok "Done!"

    local size
    size=$(du -sh "${WALLS_DIR}" 2>/dev/null | cut -f1)
    local count
    count=$(find "${WALLS_DIR}" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) 2>/dev/null | wc -l)
    log_info "Total: ${count} wallpapers (${size}) in ${WALLS_DIR/#"${HOME}"/\~}"
    return 0
}

main "$@"
