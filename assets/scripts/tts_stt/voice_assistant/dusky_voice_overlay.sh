#!/usr/bin/env bash
# Voice assistant overlay — shows animated state in a fixed-size terminal
# Spawned by the voice assistant daemon on wake, killed on idle
# Uses cursor repositioning instead of screen clear to avoid flicker

STATE_FILE="/tmp/dusky_voice_state.json"
TTS_PROGRESS="/tmp/dusky_tts_progress.json"

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

# Terminal dimensions
COLS=$(tput cols 2>/dev/null || echo 50)
ROWS=$(tput lines 2>/dev/null || echo 12)
TEXT_WIDTH=$(( COLS - 4 ))
(( TEXT_WIDTH < 10 )) && TEXT_WIDTH=10

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

    # Read TTS progress (sentence-level sync from Kokoro)
    tts_current=0
    tts_total=0
    if [[ -f "$TTS_PROGRESS" ]]; then
        tts_raw=$(cat "$TTS_PROGRESS" 2>/dev/null)
        tts_current=$(echo "$tts_raw" | grep -oP '"current": \K[0-9]+' 2>/dev/null || echo 0)
        tts_total=$(echo "$tts_raw" | grep -oP '"total": \K[0-9]+' 2>/dev/null || echo 0)
    fi

    # Re-check terminal size each frame (window may resize)
    COLS=$(tput cols 2>/dev/null || echo 50)
    ROWS=$(tput lines 2>/dev/null || echo 12)
    TEXT_WIDTH=$(( COLS - 4 ))
    (( TEXT_WIDTH < 10 )) && TEXT_WIDTH=10

    frame=$(( (frame + 1) % 10000 ))
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

            # Show response text synced to TTS sentence progress
            if [[ -n "$response_text" ]]; then
                if (( tts_total > 0 && tts_current > 0 )); then
                    # Extract sentences from TTS progress file and show up to current
                    # Parse sentences array — each entry between quotes after "sentences": [
                    visible_text=""
                    count=0
                    # Read sentences from progress JSON
                    while IFS= read -r sent; do
                        [[ -z "$sent" ]] && continue
                        count=$(( count + 1 ))
                        (( count > tts_current )) && break
                        if [[ -n "$visible_text" ]]; then
                            visible_text="$visible_text $sent"
                        else
                            visible_text="$sent"
                        fi
                    done <<< "$(echo "$tts_raw" | grep -oP '"sentences": \[\K[^\]]+' 2>/dev/null | tr ',' '\n' | sed 's/^ *"//;s/" *$//')"

                    if [[ -n "$visible_text" ]]; then
                        # Wrap text into lines
                        mapfile -t wrapped_lines <<< "$(echo "$visible_text" | fold -s -w "$TEXT_WIDTH")"
                        max_text_rows=$(( ROWS - row ))
                        total_wrapped=${#wrapped_lines[@]}
                        # If text exceeds available space, show the tail (auto-scroll)
                        if (( total_wrapped > max_text_rows )); then
                            start_idx=$(( total_wrapped - max_text_rows ))
                        else
                            start_idx=0
                        fi
                        for (( li=start_idx; li<total_wrapped && row<=ROWS; li++ )); do
                            draw_line $((row++)) "  ${wrapped_lines[$li]}"
                        done
                    fi
                else
                    # No progress yet — show first few words as preview
                    read -ra words <<< "$response_text"
                    preview="${words[*]:0:3}..."
                    draw_line $((row++)) "  ${DIM}${preview}${RESET}"
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
