#!/usr/bin/env bash
# Voice assistant overlay — shows animated state in a fixed-size terminal
# Spawned by the voice assistant daemon on wake, killed on idle
# Uses cursor repositioning instead of screen clear to avoid flicker

STATE_FILE="/tmp/dusky_voice_state.json"

# Colors (ANSI)
DIM='\033[2m'
BOLD='\033[1m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
BLUE='\033[34m'
RESET='\033[0m'
ERASE_LINE='\033[K'

# Hide cursor, clear screen once on start
printf '\033[?25l\033[2J'
trap 'printf "\033[?25h"; exit 0' EXIT INT TERM

frame=0
last_state=""
speak_frame=0

# Terminal dimensions
COLS=$(tput cols 2>/dev/null || echo 50)
ROWS=$(tput lines 2>/dev/null || echo 12)
TEXT_WIDTH=$(( COLS - 4 ))
(( TEXT_WIDTH < 10 )) && TEXT_WIDTH=10

# Frames per word for TTS sync
# At 80ms per frame, ~2.5 words/sec = 1 word every 5 frames
FRAMES_PER_WORD=5

# Draw a line at row, erasing remainder
draw_line() {
    local row=$1 content=$2
    printf "\033[%d;1H%b${ERASE_LINE}" "$row" "$content"
}

# Clear rows from start to end of screen
clear_from() {
    local start=$1
    for (( r=start; r<=ROWS; r++ )); do
        printf "\033[%d;1H${ERASE_LINE}" "$r"
    done
}

while true; do
    # Read state file
    cur_state=""
    user_text=""
    response_text=""
    tool_use=""
    if [[ -f "$STATE_FILE" ]]; then
        raw=$(cat "$STATE_FILE" 2>/dev/null)
        cur_state=$(echo "$raw" | grep -oP '"state": "\K[^"]+' 2>/dev/null)
        user_text=$(echo "$raw" | grep -oP '"user_text": "\K[^"]+' 2>/dev/null)
        response_text=$(echo "$raw" | grep -oP '"response_text": "\K[^"]+' 2>/dev/null)
        tool_use=$(echo "$raw" | grep -oP '"tool_use": "\K[^"]+' 2>/dev/null)
    fi

    frame=$(( (frame + 1) % 10000 ))

    # Track when speaking starts for word reveal timing
    if [[ "$cur_state" == "SPEAKING" && "$last_state" != "SPEAKING" ]]; then
        speak_frame=0
    elif [[ "$cur_state" == "SPEAKING" ]]; then
        speak_frame=$(( speak_frame + 1 ))
    fi
    last_state="$cur_state"

    row=1

    case "$cur_state" in
        WAKE_DETECTED)
            draw_line $((row++)) "${CYAN}${BOLD} 󰍬 Hey!${RESET}"
            draw_line $((row++)) "${DIM}  Preparing...${RESET}"
            ;;
        RECORDING)
            mic_frames=("●      " "●●     " "●●●    " "●●●●   " "●●●●●  " " ●●●●● " "  ●●●●●" "   ●●●●" "    ●●●" "     ●●" "      ●" "       ")
            idx=$(( frame % ${#mic_frames[@]} ))
            draw_line $((row++)) "${GREEN}${BOLD} 󰍬 Listening${RESET}"
            draw_line $((row++)) "  ${GREEN}${mic_frames[$idx]}${RESET}"
            ;;
        TRANSCRIBING)
            spin_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
            idx=$(( frame % ${#spin_chars[@]} ))
            if [[ -n "$user_text" ]]; then
                draw_line $((row++)) "${YELLOW}${BOLD} 󰗊 You said:${RESET}"
                while IFS= read -r line; do
                    (( row > ROWS )) && break
                    draw_line $((row++)) "  ${line}"
                done <<< "$(echo "$user_text" | fold -s -w "$TEXT_WIDTH")"
            else
                draw_line $((row++)) "${YELLOW}${BOLD} 󰗊 Transcribing ${spin_chars[$idx]}${RESET}"
            fi
            ;;
        THINKING)
            think_frames=("   " ".  " ".. " "..." ".. " ".  ")
            idx=$(( frame / 3 % ${#think_frames[@]} ))
            if [[ -n "$tool_use" ]]; then
                spin_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
                sidx=$(( frame % ${#spin_chars[@]} ))
                draw_line $((row++)) "${BLUE}${BOLD} 󰊄 ${tool_use} ${spin_chars[$sidx]}${RESET}"
            else
                draw_line $((row++)) "${MAGENTA}${BOLD} 󰧑 Thinking${think_frames[$idx]}${RESET}"
            fi
            if [[ -n "$user_text" ]]; then
                while IFS= read -r line; do
                    (( row > ROWS )) && break
                    draw_line $((row++)) " ${DIM}${line}${RESET}"
                done <<< "$(echo "$user_text" | fold -s -w "$TEXT_WIDTH")"
            fi
            ;;
        SPEAKING)
            # Wave animation header
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
            draw_line $((row++)) "${CYAN}${BOLD} 󰔊 Speaking${RESET}  ${CYAN}${wave[*]}${RESET}"

            # Word-by-word reveal synced to TTS speed
            if [[ -n "$response_text" ]]; then
                # How many words to reveal based on frames elapsed
                words_to_show=$(( speak_frame / FRAMES_PER_WORD + 1 ))

                # Split response into words
                read -ra all_words <<< "$response_text"
                total_words=${#all_words[@]}

                # Cap at total words
                (( words_to_show > total_words )) && words_to_show=$total_words

                # Build visible text from first N words
                visible_text="${all_words[*]:0:$words_to_show}"

                # Wrap and display
                if [[ -n "$visible_text" ]]; then
                    while IFS= read -r line; do
                        (( row > ROWS )) && break
                        draw_line $((row++)) "  ${line}"
                    done <<< "$(echo "$visible_text" | fold -s -w "$TEXT_WIDTH")"
                fi
            fi
            ;;
        LISTENING_FOLLOWUP)
            mic_frames=("●      " "●●     " "●●●    " "●●●●   " "●●●●●  " " ●●●●● " "  ●●●●●" "   ●●●●" "    ●●●" "     ●●" "      ●" "       ")
            idx=$(( frame % ${#mic_frames[@]} ))
            draw_line $((row++)) "${GREEN}${BOLD} 󰍬 Follow-up?${RESET}"
            draw_line $((row++)) "  ${GREEN}${mic_frames[$idx]}${RESET}"
            ;;
        *)
            draw_line $((row++)) "${DIM} 󰍬 Dusky Voice${RESET}"
            draw_line $((row++)) "${DIM}  Ready${RESET}"
            ;;
    esac

    # Clear leftover lines
    clear_from $row

    sleep 0.08
done
