#!/usr/bin/env bash
# Voice assistant overlay — shows animated state in a small terminal
# Spawned by the voice assistant daemon on wake, killed on idle
# No cava — uses pure unicode animations to avoid audio interference

STATE_FILE="/tmp/dusky_voice_state.json"

# Colors (ANSI)
DIM='\033[2m'
BOLD='\033[1m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
RESET='\033[0m'

# Hide cursor
printf '\033[?25l'
trap 'printf "\033[?25l"; exit 0' EXIT INT TERM

frame=0

while true; do
    # Read state file (lightweight — no python, just bash)
    cur_state=""
    user_text=""
    if [[ -f "$STATE_FILE" ]]; then
        # Simple parsing without python dependency
        while IFS=: read -r key val; do
            key="${key//[\"{, ]/}"
            val="${val//[\",]/}"
            val="${val# }"
            case "$key" in
                state) cur_state="$val" ;;
                user_text) user_text="$val" ;;
            esac
        done < "$STATE_FILE"
    fi

    # Animated elements based on frame counter
    frame=$(( (frame + 1) % 120 ))
    pulse=$(( frame % 8 ))

    # Clear and draw
    printf '\033[2J\033[H'

    case "$cur_state" in
        WAKE_DETECTED)
            printf "${CYAN}${BOLD} 󰍬 Hey!${RESET}\n"
            printf "${DIM}  Preparing...${RESET}"
            ;;
        RECORDING)
            # Animated mic with pulsing dots
            mic_frames=("●    " "●●   " "●●●  " "●●●● " "●●●●●" " ●●●●" "  ●●●" "   ●●" "    ●" "     ")
            idx=$(( frame % ${#mic_frames[@]} ))
            printf "${GREEN}${BOLD} 󰍬 Listening${RESET}\n"
            printf "  ${GREEN}${mic_frames[$idx]}${RESET}"
            ;;
        TRANSCRIBING)
            # Spinning indicator
            spin_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
            idx=$(( frame % ${#spin_chars[@]} ))
            printf "${YELLOW}${BOLD} 󰗊 Transcribing ${spin_chars[$idx]}${RESET}\n"
            if [[ -n "$user_text" ]]; then
                printf "  ${DIM}\"${user_text:0:30}\"${RESET}"
            fi
            ;;
        THINKING)
            # Animated thinking dots
            think_frames=("   " ".  " ".. " "..." ".. " ".  ")
            idx=$(( frame / 3 % ${#think_frames[@]} ))
            printf "${MAGENTA}${BOLD} 󰧑 Thinking${think_frames[$idx]}${RESET}\n"
            if [[ -n "$user_text" ]]; then
                printf "  ${DIM}\"${user_text:0:30}\"${RESET}"
            fi
            ;;
        SPEAKING)
            # Animated waveform using unicode blocks (no audio capture)
            wave=()
            for i in {0..11}; do
                # Generate pseudo-random wave based on frame + position
                v=$(( (frame * 7 + i * 13) % 17 ))
                if (( v > 12 )); then h="█"
                elif (( v > 9 )); then h="▆"
                elif (( v > 6 )); then h="▄"
                elif (( v > 3 )); then h="▂"
                else h="▁"
                fi
                wave+=("$h")
            done
            printf "${CYAN}${BOLD} 󰔊 Speaking${RESET}\n"
            printf "  ${CYAN}${wave[*]}${RESET}"
            ;;
        LISTENING_FOLLOWUP)
            mic_frames=("●    " "●●   " "●●●  " "●●●● " "●●●●●" " ●●●●" "  ●●●" "   ●●" "    ●" "     ")
            idx=$(( frame % ${#mic_frames[@]} ))
            printf "${GREEN}${BOLD} 󰍬 Follow-up?${RESET}\n"
            printf "  ${GREEN}${mic_frames[$idx]}${RESET}"
            ;;
        *)
            printf "${DIM} 󰍬 Dusky Voice${RESET}\n"
            printf "${DIM}  Ready${RESET}"
            ;;
    esac

    sleep 0.08
done
