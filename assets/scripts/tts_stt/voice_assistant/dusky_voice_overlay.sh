#!/usr/bin/env bash
# Voice assistant overlay — shows animated state in a fixed-size terminal
# Uses scroll region: row 1 = fixed header, rows 2+ = scrolling text area

STATE_FILE="/tmp/dusky_voice_state.json"
TTS_PROGRESS="/tmp/dusky_tts_progress.json"

# Colors
DIM='\033[2m'
BOLD='\033[1m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
BLUE='\033[34m'
RESET='\033[0m'

# Alternate screen, hide cursor
printf '\033[?1049h\033[?25l\033[2J'
trap 'printf "\033[?25h\033[?1049l"; exit 0' EXIT INT TERM

frame=0
prev_state=""
printed_sentences=0  # how many sentences we've already printed to the text area

# Write header at row 1 (fixed, outside scroll region)
draw_header() {
    printf '\033[1;1H\033[K%b' "$1"
}

# Set up scroll region (rows 2 to bottom) and move cursor there
setup_scroll_region() {
    local rows
    rows=$(tput lines 2>/dev/null || echo 20)
    printf '\033[2;%dr' "$rows"
}

# Print text into scroll region (appends, terminal handles scrolling)
print_text() {
    local cols
    cols=$(tput cols 2>/dev/null || echo 50)
    local width=$(( cols - 4 ))
    (( width < 10 )) && width=10
    # Move to bottom of scroll region and print — terminal scrolls up naturally
    printf '\033[999;1H'
    echo "$1" | fold -s -w "$width" | while IFS= read -r line; do
        printf '  %s\n' "$line"
    done
}

# Clear text area and reset printed count
clear_text_area() {
    local rows
    rows=$(tput lines 2>/dev/null || echo 20)
    # Clear scroll region
    for (( r=2; r<=rows; r++ )); do
        printf '\033[%d;1H\033[K' "$r"
    done
    printf '\033[2;1H'
    printed_sentences=0
}

setup_scroll_region

while true; do
    # Read state
    cur_state=""
    user_text=""
    response_text=""
    tool_use=""
    if [[ -f "$STATE_FILE" ]]; then
        IFS=$'\x1e' read -r cur_state user_text response_text tool_use < <(
            jq -rj '[.state // "", .user_text // "", .response_text // "", .tool_use // ""] | join("\u001e")' "$STATE_FILE" 2>/dev/null
        ) || true
    fi

    # Read TTS progress
    tts_current=0
    tts_total=0
    if [[ -f "$TTS_PROGRESS" ]]; then
        IFS=$'\x1e' read -r tts_current tts_total < <(
            jq -rj '[.current // 0, .total // 0] | join("\u001e")' "$TTS_PROGRESS" 2>/dev/null
        ) || true
    fi

    frame=$(( (frame + 1) % 10000 ))

    # On state change, clear text area
    if [[ "$cur_state" != "$prev_state" ]]; then
        clear_text_area
        setup_scroll_region
        prev_state="$cur_state"
    fi

    case "$cur_state" in
        WAKE_DETECTED)
            draw_header "${CYAN}${BOLD} 󰍬 Hey! ${DIM}Preparing...${RESET}"
            ;;
        RECORDING)
            mic_frames=("●      " "●●     " "●●●    " "●●●●   " "●●●●●  " " ●●●●● " "  ●●●●●" "   ●●●●" "    ●●●" "     ●●" "      ●" "       ")
            idx=$(( frame % ${#mic_frames[@]} ))
            draw_header "${GREEN}${BOLD} 󰍬 Listening  ${mic_frames[$idx]}${RESET}"
            ;;
        TRANSCRIBING)
            spin_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
            idx=$(( frame % ${#spin_chars[@]} ))
            if [[ -n "$user_text" ]]; then
                draw_header "${YELLOW}${BOLD} 󰗊 You said:${RESET}"
                # Print user text once on state entry
                if (( printed_sentences == 0 )); then
                    print_text "$user_text"
                    printed_sentences=1
                fi
            else
                draw_header "${YELLOW}${BOLD} 󰗊 Transcribing ${spin_chars[$idx]}${RESET}"
            fi
            ;;
        THINKING)
            think_frames=("   " ".  " ".. " "..." ".. " ".  ")
            idx=$(( frame / 3 % ${#think_frames[@]} ))
            if [[ -n "$tool_use" ]]; then
                spin_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
                sidx=$(( frame % ${#spin_chars[@]} ))
                draw_header "${BLUE}${BOLD} 󰊄 ${tool_use} ${spin_chars[$sidx]}${RESET}"
            else
                draw_header "${MAGENTA}${BOLD} 󰧑 Thinking${think_frames[$idx]}${RESET}"
            fi
            # Print user text once
            if [[ -n "$user_text" ]] && (( printed_sentences == 0 )); then
                print_text "${DIM}${user_text}${RESET}"
                printed_sentences=1
            fi
            ;;
        SPEAKING)
            # Animated wave header
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
            draw_header "${CYAN}${BOLD} 󰔊 Speaking${RESET}  ${CYAN}${wave[*]}${RESET}"

            # Print NEW sentences as they become available (incremental)
            if (( tts_current > printed_sentences && tts_total > 0 )); then
                # Get sentences from printed_sentences to tts_current
                mapfile -t new_sents < <(
                    jq -r ".sentences[${printed_sentences}:${tts_current}][]" "$TTS_PROGRESS" 2>/dev/null
                )
                for sent in "${new_sents[@]}"; do
                    [[ -z "$sent" ]] && continue
                    print_text "$sent"
                done
                printed_sentences=$tts_current
            fi
            ;;
        LISTENING_FOLLOWUP)
            mic_frames=("●      " "●●     " "●●●    " "●●●●   " "●●●●●  " " ●●●●● " "  ●●●●●" "   ●●●●" "    ●●●" "     ●●" "      ●" "       ")
            idx=$(( frame % ${#mic_frames[@]} ))
            draw_header "${GREEN}${BOLD} 󰍬 Follow-up?  ${mic_frames[$idx]}${RESET}"
            ;;
        *)
            draw_header "${DIM} 󰍬 Dusky Voice — Ready${RESET}"
            ;;
    esac

    sleep 0.08
done
