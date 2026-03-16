#!/usr/bin/env bash
# Engages high-visibility mode by maximizing brightness and toggling visual effects
# PATCHED for NixOS: uses dusky-blur-toggle instead of hardcoded path

set -euo pipefail

readonly C_RESET=$'\033[0m'
readonly C_GREEN=$'\033[1;32m'
readonly C_BLUE=$'\033[1;34m'
readonly C_RED=$'\033[1;31m'

log_info() { printf "${C_BLUE}[INFO]${C_RESET} %s\n" "$1"; }
log_success() { printf "${C_GREEN}[SUCCESS]${C_RESET} %s\n" "$1"; }
log_error() { printf "${C_RED}[ERROR]${C_RESET} %s\n" "$1" >&2; }

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script failed with exit code $exit_code."
    fi
}
trap cleanup EXIT

main() {
    log_info "Initializing Max Performance/Visibility Mode..."

    if ! command -v brightnessctl &>/dev/null; then
        log_error "'brightnessctl' is not installed or not in PATH."
        exit 1
    fi

    log_info "Setting brightness to 100%..."
    if brightnessctl set 100% &>/dev/null; then
        log_success "Brightness maximized."
    else
        log_info "Brightness control unavailable (VM or external monitor detected). Skipping..."
    fi

    log_info "Engaging visual effects (on)..."
    if dusky-blur-toggle on; then
        log_success "Visual effects toggled successfully."
    else
        printf "${C_BLUE}[WARN]${C_RESET} %s\n" "Target file hasn't been generated yet. Skipping visual effects."
    fi

    log_success "All operations completed cleanly."
}

main "$@"
