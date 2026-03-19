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

# Directories to exclude from category listing
readonly EXCLUDED_DIRS=".github"

# --- Terminal Setup ----------------------------------------------------------
readonly RST=$'\033[0m' BOLD=$'\033[1m'
readonly RED=$'\033[31m' GRN=$'\033[32m' YEL=$'\033[33m' BLU=$'\033[34m'

# --- Logging -----------------------------------------------------------------
log_info()  { printf '%s[INFO]%s %s\n' "${BLU}" "${RST}" "$*"; }
log_ok()    { printf '%s[ OK ]%s %s\n' "${GRN}" "${RST}" "$*"; }
log_warn()  { printf '%s[WARN]%s %s\n' "${YEL}" "${RST}" "$*" >&2; }
log_error() { printf '%s[ERR ]%s %s\n' "${RED}" "${RST}" "$*" >&2; }

# --- Dependency Verification -------------------------------------------------
check_deps() {
    local -a missing=()
    local dep
    for dep in curl jq gum; do
        command -v "${dep}" &>/dev/null || missing+=("${dep}")
    done
    if (( ${#missing[@]} > 0 )); then
        log_error "Missing dependencies: ${missing[*]}"
        return 1
    fi
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
    local downloaded=0 skipped=0 failed=0

    mkdir -p "$dest"

    local files
    files=$(fetch_category_files "$category") || return 1
    local total
    total=$(echo "$files" | wc -l)

    while IFS= read -r filename; do
        [[ -z "$filename" ]] && continue
        local filepath="${dest}/${filename}"

        if [[ -f "$filepath" ]]; then
            skipped=$((skipped + 1))
            continue
        fi

        local encoded_category encoded_filename
        encoded_category=$(printf '%s' "$category" | sed 's/ /%20/g')
        encoded_filename=$(printf '%s' "$filename" | sed 's/ /%20/g')

        if curl -sfL --http1.1 --retry 2 --retry-delay 3 --connect-timeout 15 \
                -o "$filepath" "${RAW_BASE}/${encoded_category}/${encoded_filename}"; then
            downloaded=$((downloaded + 1))
        else
            failed=$((failed + 1))
            rm -f "$filepath"
        fi
    done <<< "$files"

    if (( failed > 0 )); then
        log_warn "${category}: ${downloaded} new, ${skipped} cached, ${failed} failed"
    else
        log_ok "${category}: ${downloaded} new, ${skipped} cached"
    fi
}

# --- Main Entry Point --------------------------------------------------------
main() {
    gum style --bold --foreground 212 --border rounded --border-foreground 240 \
        --padding "0 2" --margin "1 0" \
        "dharmx/walls Wallpaper Installer" \
        "github.com/${REPO}"

    check_deps

    # Fetch categories
    local categories_raw
    categories_raw=$(gum spin --spinner dot --title "Fetching categories..." \
        --show-output -- bash -c "
            curl -sf '${API_BASE}/git/trees/${BRANCH}' \
                -H 'Accept: application/vnd.github+json' \
            | jq -r '.tree[] | select(.type == \"tree\") | .path' | sort
        ") || { log_error "Failed to fetch categories."; return 1; }

    local -a categories=()
    while IFS= read -r cat; do
        [[ -z "$cat" ]] && continue
        # Skip excluded directories
        for excl in ${EXCLUDED_DIRS}; do
            [[ "$cat" == "$excl" ]] && continue 2
        done
        categories+=("$cat")
    done <<< "$categories_raw"

    if (( ${#categories[@]} == 0 )); then
        log_error "No categories found."
        return 1
    fi

    # Build display labels — mark already-downloaded categories
    local -a labels=()
    local -a gum_args=(
        gum choose --no-limit
        --header "Select categories to download:"
        --cursor-prefix "[ ] "
        --selected-prefix "[✕] "
        --unselected-prefix "[ ] "
        --height 20
    )

    for cat in "${categories[@]}"; do
        if [[ -d "${WALLS_DIR}/${cat}" ]]; then
            labels+=("${cat} ✓")
            gum_args+=(--selected "${cat} ✓")
        else
            labels+=("$cat")
        fi
    done

    printf '\n'
    gum style --faint "Use ↑/↓ to navigate, space to select, a to toggle all, enter to confirm"
    gum style --faint "✓ = already downloaded (will skip existing files)"
    printf '\n'

    local selected_raw
    selected_raw=$("${gum_args[@]}" "${labels[@]}") || {
        log_info "Aborted."
        return 0
    }

    # Strip the ✓ suffix to get clean category names
    local -a selected=()
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        line="${line% ✓}"
        selected+=("$line")
    done <<< "$selected_raw"

    if (( ${#selected[@]} == 0 )); then
        log_info "No categories selected."
        return 0
    fi

    printf '\n'
    gum style --bold --foreground 39 "Downloading ${#selected[@]} categories"
    mkdir -p "$WALLS_DIR"

    local cat_done=0
    for cat in "${selected[@]}"; do
        cat_done=$((cat_done + 1))
        printf '\n'
        gum style --foreground 245 "[${cat_done}/${#selected[@]}] ${cat}"
        download_category "$cat" || log_warn "Failed to download ${cat}, continuing..."
    done

    printf '\n'
    local size count
    size=$(du -sh "${WALLS_DIR}" 2>/dev/null | cut -f1)
    count=$(find "${WALLS_DIR}" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) 2>/dev/null | wc -l)

    gum style --bold --foreground 82 --border rounded --border-foreground 240 \
        --padding "0 2" \
        "Download complete!" \
        "${count} wallpapers (${size})" \
        "${WALLS_DIR/#"${HOME}"/\~}"
}

main "$@"
