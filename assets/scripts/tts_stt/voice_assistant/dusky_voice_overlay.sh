#!/usr/bin/env bash
# Voice assistant overlay — shows animated state in a small terminal
# Spawned by the voice assistant daemon on wake, killed on idle
# Pure unicode animations — no audio capture

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
trap 'printf "\033[?25h"; exit 0' EXIT INT TERM

frame=0

while true; do
    # Read state file
    cur_state=""
    user_text=""
    if [[ -f "$STATE_FILE" ]]; then
        raw=$(cat "$STATE_FILE" 2>/dev/null)
        cur_state=$(echo "$raw" | grep -oP '"state": "\K[^"]+' 2>/dev/null)
        user_text=$(echo "$raw" | grep -oP '"user_text": "\K[^"]+' 2>/dev/null)
    fi

    frame=$(( (frame + 1) % 120 ))

    # Clear and draw
    printf '\033[2J\033[H'

    case "$cur_state" in
        WAKE_DETECTED)
            printf "${CYAN}${BOLD} 󰍬 Hey!${RESET}\n"
            printf "${DIM}  Preparing...${RESET}"
            ;;
        RECORDING)
            mic_frames=("●      " "●●     " "●●●    " "●●●●   " "●●●●●  " " ●●●●● " "  ●●●●●" "   ●●●●" "    ●●●" "     ●●" "      ●" "       ")
            idx=$(( frame % ${#mic_frames[@]} ))
            printf "${GREEN}${BOLD} 󰍬 Listening${RESET}\n"
            printf "  ${GREEN}${mic_frames[$idx]}${RESET}"
            ;;
        TRANSCRIBING)
            spin_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
            idx=$(( frame % ${#spin_chars[@]} ))
            if [[ -n "$user_text" ]]; then
                printf "${YELLOW}${BOLD} 󰗊 ${spin_chars[$idx]}${RESET} ${user_text}\n"
            else
                printf "${YELLOW}${BOLD} 󰗊 Transcribing ${spin_chars[$idx]}${RESET}\n"
            fi
            ;;
        THINKING)
            think_frames=("   " ".  " ".. " "..." ".. " ".  ")
            idx=$(( frame / 3 % ${#think_frames[@]} ))
            printf "${MAGENTA}${BOLD} 󰧑 Thinking${think_frames[$idx]}${RESET}\n"
            if [[ -n "$user_text" ]]; then
                printf " ${DIM}${user_text}${RESET}\n"
            fi
            ;;
        SPEAKING)
            wave=()
            for i in {0..14}; do
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
            printf " ${CYAN}${wave[*]}${RESET}"
            ;;
        LISTENING_FOLLOWUP)
            mic_frames=("●      " "●●     " "●●●    " "●●●●   " "●●●●●  " " ●●●●● " "  ●●●●●" "   ●●●●" "    ●●●" "     ●●" "      ●" "       ")
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
