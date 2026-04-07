{ pkgs, dusky }:

let
  # Use patched scripts from dusky-nix (not upstream dusky)
  scriptDir = ../../assets/scripts/theme_matugen;
  gtkDir = "${dusky}/user_scripts/gtk";
in
pkgs.symlinkJoin {
  name = "dusky-theme-scripts";
  paths = [
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-theme-ctl";
      runtimeInputs = with pkgs; [ awww matugen coreutils findutils gnugrep gawk procps glib gsettings-desktop-schemas python3 ];
      text = builtins.readFile "${scriptDir}/theme_ctl.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-matugen-presets";
      runtimeInputs = with pkgs; [ matugen rofi coreutils ];
      text = builtins.readFile "${scriptDir}/dusky_matugen_presets.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-theme-favorites";
      runtimeInputs = with pkgs; [ coreutils ];
      text = builtins.readFile "${scriptDir}/theme_favorites_ctl.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-papirus-folder-colors";
      runtimeInputs = with pkgs; [ python3 papirus-folders gsettings-desktop-schemas glib ];
      text = ''exec python3 ${gtkDir}/papirus_folder_colors.py "$@"'';
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-wallpaper-fetch";
      runtimeInputs = with pkgs; [ curl jq coreutils awww matugen procps ];
      text = ''
        set -euo pipefail

        REPO="dusklinux/images"
        CACHE_DIR="''${HOME}/.cache/dusky/wallpaper-index"
        DARK_LIST="''${CACHE_DIR}/dark.list"
        LIGHT_LIST="''${CACHE_DIR}/light.list"
        WALL_DIR="''${HOME}/Pictures/wallpapers"
        CACHE_MAX_AGE=86400  # refresh file list once per day

        STATE_FILE="''${HOME}/.config/dusky/settings/dusky_theme/state.conf"

        log()  { printf '\033[1;34m::\033[0m %s\n' "$*" >&2; }
        err()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; }
        die()  { err "$*"; exit 1; }

        # Determine current theme mode from dusky state
        get_mode() {
          if [[ -f "$STATE_FILE" ]]; then
            grep -oP '(?<=THEME_MODE=).*' "$STATE_FILE" 2>/dev/null || echo "dark"
          else
            echo "dark"
          fi
        }

        # Fetch or use cached file listing from GitHub API
        refresh_index() {
          local mode="$1" list_file tree_url
          [[ "$mode" == "light" ]] && list_file="$LIGHT_LIST" || list_file="$DARK_LIST"

          mkdir -p "$CACHE_DIR"

          # Use cache if fresh enough
          if [[ -f "$list_file" ]]; then
            local age=$(( $(date +%s) - $(stat -c %Y "$list_file") ))
            if (( age < CACHE_MAX_AGE )); then
              return 0
            fi
          fi

          log "Refreshing ''${mode} wallpaper index from GitHub..."

          # Get tree SHA for the folder
          local tree_sha
          tree_sha=$(curl -sf "https://api.github.com/repos/''${REPO}/git/trees/main" \
            | jq -r ".tree[] | select(.path == \"''${mode}\") | .sha") \
            || die "Failed to fetch repo tree"

          [[ -n "$tree_sha" ]] || die "Could not find ''${mode}/ directory in repo"

          # Get file listing
          curl -sf "https://api.github.com/repos/''${REPO}/git/trees/''${tree_sha}" \
            | jq -r '.tree[].path' > "$list_file" \
            || die "Failed to fetch file listing"

          log "Indexed $(wc -l < "$list_file") ''${mode} wallpapers"
        }

        # Pick a random file from the index and download it
        fetch_random() {
          local mode="$1" list_file
          [[ "$mode" == "light" ]] && list_file="$LIGHT_LIST" || list_file="$DARK_LIST"

          refresh_index "$mode"

          local count
          count=$(wc -l < "$list_file")
          (( count > 0 )) || die "No wallpapers in index"

          local pick
          pick=$(shuf -n 1 "$list_file")

          mkdir -p "$WALL_DIR"

          local dest="''${WALL_DIR}/''${pick}"

          if [[ -f "$dest" ]]; then
            log "Already have: ''${pick}"
          else
            log "Downloading: ''${mode}/''${pick}"
            curl -sfL "https://raw.githubusercontent.com/''${REPO}/main/''${mode}/''${pick}" \
              -o "$dest" || die "Failed to download ''${pick}"
          fi

          echo "$dest"
        }

        # --- Main ---
        MODE=$(get_mode)

        # Allow overriding mode: dusky-wallpaper-fetch [dark|light]
        if [[ -n "''${1:-}" ]]; then
          case "$1" in
            dark|light) MODE="$1" ;;
            --refresh-index)
              refresh_index dark
              refresh_index light
              exit 0
              ;;
            *) die "Usage: dusky-wallpaper-fetch [dark|light|--refresh-index]" ;;
          esac
        fi

        WALLPAPER=$(fetch_random "$MODE")

        log "Applying: ''${WALLPAPER##*/}"

        # Ensure awww is running
        if ! pgrep -xu "$UID" awww-daemon >/dev/null 2>&1; then
          awww-daemon --format xrgb >/dev/null 2>&1 &
          sleep 1
        fi

        awww img "$WALLPAPER" \
          --transition-type grow \
          --transition-duration 2 \
          --transition-fps 60

        # Generate colors with matugen
        if [[ -f "''${HOME}/.config/matugen/config.toml" ]]; then
          log "Generating colors with matugen..."
          matugen -c "''${HOME}/.config/matugen/config.toml" \
            --mode "$MODE" image "$WALLPAPER" || true
        fi

        log "Done!"
      '';
    })
  ];
}
