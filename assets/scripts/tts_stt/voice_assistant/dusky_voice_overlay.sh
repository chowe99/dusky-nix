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
scroll_offset=0
last_response=""
last_state=""

# Terminal dimensions
COLS=$(tput cols 2>/dev/null || echo 50)
ROWS=$(tput lines 2>/dev/null || echo 12)
TEXT_WIDTH=$(( COLS - 4 ))
(( TEXT_WIDTH < 10 )) && TEXT_WIDTH=10
# Reserve lines: 1 header + 1 animation + rest for text
TEXT_ROWS=$(( ROWS - 3 ))
(( TEXT_ROWS < 2 )) && TEXT_ROWS=2

wrap_text() {
    echo "$1" | fold -s -w "$TEXT_WIDTH"
}

# Draw a line, erasing to end to overwrite old content
draw_line() {
    local row=$1 content=$2
    printf "\033[%d;1H%b${ERASE_LINE}" "$row" "$content"
}

# Clear remaining rows from a starting row
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

    frame=$(( (frame + 1) % 120 ))

    # Reset scroll when response changes or state changes away from speaking
    if [[ "$cur_state" == "SPEAKING" && "$response_text" != "$last_response" ]]; then
        scroll_offset=0
        last_response="$response_text"
    elif [[ "$cur_state" != "SPEAKING" && "$last_state" == "SPEAKING" ]]; then
        scroll_offset=0
        last_response=""
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
                    draw_line $((row++)) "  ${line}"
                done <<< "$(wrap_text "$user_text")"
            else
                draw_line $((row++)) "${YELLOW}${BOLD} 󰗊 Transcribing ${spin_chars[$idx]}${RESET}"
            fi
            ;;
        THINKING)
            think_frames=("   " ".  " ".. " "..." ".. " ".  ")
            idx=$(( frame / 3 % ${#think_frames[@]} ))
            if [[ -n "$tool_use" ]]; then
                # Show tool usage with spinning icon
                spin_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
                sidx=$(( frame % ${#spin_chars[@]} ))
                draw_line $((row++)) "${BLUE}${BOLD} 󰊄 ${tool_use} ${spin_chars[$sidx]}${RESET}"
            else
                draw_line $((row++)) "${MAGENTA}${BOLD} 󰧑 Thinking${think_frames[$idx]}${RESET}"
            fi
            if [[ -n "$user_text" ]]; then
                while IFS= read -r line; do
                    draw_line $((row++)) " ${DIM}${line}${RESET}"
                done <<< "$(wrap_text "$user_text")"
            fi
            ;;
        SPEAKING)
            # Wave animation on first line
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

            # Show response text with auto-scroll
            if [[ -n "$response_text" ]]; then
                # Wrap text into lines array
                mapfile -t wrapped_lines <<< "$(wrap_text "$response_text")"
                total_lines=${#wrapped_lines[@]}

                # Auto-scroll: advance every ~8 frames (~0.6s per line)
                if (( total_lines > TEXT_ROWS )); then
                    max_scroll=$(( total_lines - TEXT_ROWS ))
                    scroll_offset=$(( (frame / 8) % (max_scroll + TEXT_ROWS + 5) ))
                    # Clamp
                    (( scroll_offset > max_scroll )) && scroll_offset=$max_scroll
                fi

                # Draw visible lines
                for (( i=scroll_offset; i < scroll_offset + TEXT_ROWS && i < total_lines; i++ )); do
                    draw_line $((row++)) "  ${wrapped_lines[$i]}"
                done

                # Scroll indicator
                if (( total_lines > TEXT_ROWS )); then
                    pos=$(( scroll_offset * 100 / (total_lines - TEXT_ROWS) ))
                    draw_line $((row++)) "${DIM}  ── ${pos}% ──${RESET}"
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

    # Clear any leftover lines below current content
    clear_from $row

    sleep 0.08
done
