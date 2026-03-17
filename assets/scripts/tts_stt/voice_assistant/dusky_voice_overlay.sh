#!/usr/bin/env bash
# Voice assistant overlay — shows animated state in a fixed-size terminal
# Spawned by the voice assistant daemon on wake, killed on idle
# Uses buffer-based rendering to avoid flicker

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

# Hide cursor, clear screen once on start
printf '\033[?25l\033[2J'
trap 'printf "\033[?25h"; exit 0' EXIT INT TERM

frame=0

while true; do
    # Terminal dimensions (re-check each frame)
    COLS=$(tput cols 2>/dev/null || echo 50)
    ROWS=$(tput lines 2>/dev/null || echo 20)
    TEXT_WIDTH=$(( COLS - 4 ))
    (( TEXT_WIDTH < 10 )) && TEXT_WIDTH=10

    # Read state file using jq for proper JSON parsing (single jq call)
    cur_state=""
    user_text=""
    response_text=""
    tool_use=""
    if [[ -f "$STATE_FILE" ]]; then
        IFS=$'\x1e' read -r cur_state user_text response_text tool_use < <(
            jq -rj '[.state // "", .user_text // "", .response_text // "", .tool_use // ""] | join("\u001e")' "$STATE_FILE" 2>/dev/null
        ) || true
    fi

    # Read TTS progress (single jq call)
    tts_current=0
    tts_total=0
    tts_sentences=()
    if [[ -f "$TTS_PROGRESS" ]]; then
        IFS=$'\x1e' read -r tts_current tts_total < <(
            jq -rj '[.current // 0, .total // 0] | join("\u001e")' "$TTS_PROGRESS" 2>/dev/null
        ) || true
        if (( tts_total > 0 && tts_current > 0 )); then
            mapfile -t tts_sentences < <(jq -r ".sentences[0:${tts_current}][]" "$TTS_PROGRESS" 2>/dev/null)
        fi
    fi

    frame=$(( (frame + 1) % 10000 ))

    # Build frame into array of lines
    lines=()

    case "$cur_state" in
        WAKE_DETECTED)
            lines+=("$(printf "${CYAN}${BOLD} 󰍬 Hey!${RESET}")")
            lines+=("$(printf "${DIM}  Preparing...${RESET}")")
            ;;
        RECORDING)
            mic_frames=("●      " "●●     " "●●●    " "●●●●   " "●●●●●  " " ●●●●● " "  ●●●●●" "   ●●●●" "    ●●●" "     ●●" "      ●" "       ")
            idx=$(( frame % ${#mic_frames[@]} ))
            lines+=("$(printf "${GREEN}${BOLD} 󰍬 Listening${RESET}")")
            lines+=("$(printf "  ${GREEN}%s${RESET}" "${mic_frames[$idx]}")")
            ;;
        TRANSCRIBING)
            spin_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
            idx=$(( frame % ${#spin_chars[@]} ))
            if [[ -n "$user_text" ]]; then
                lines+=("$(printf "${YELLOW}${BOLD} 󰗊 You said:${RESET}")")
                while IFS= read -r wline; do
                    lines+=("$(printf "  %s" "$wline")")
                done <<< "$(echo "$user_text" | fold -s -w "$TEXT_WIDTH")"
            else
                lines+=("$(printf "${YELLOW}${BOLD} 󰗊 Transcribing %s${RESET}" "${spin_chars[$idx]}")")
            fi
            ;;
        THINKING)
            think_frames=("   " ".  " ".. " "..." ".. " ".  ")
            idx=$(( frame / 3 % ${#think_frames[@]} ))
            if [[ -n "$tool_use" ]]; then
                spin_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
                sidx=$(( frame % ${#spin_chars[@]} ))
                lines+=("$(printf "${BLUE}${BOLD} 󰊄 %s %s${RESET}" "$tool_use" "${spin_chars[$sidx]}")")
            else
                lines+=("$(printf "${MAGENTA}${BOLD} 󰧑 Thinking%s${RESET}" "${think_frames[$idx]}")")
            fi
            if [[ -n "$user_text" ]]; then
                while IFS= read -r wline; do
                    lines+=("$(printf " ${DIM}%s${RESET}" "$wline")")
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
            lines+=("$(printf "${CYAN}${BOLD} 󰔊 Speaking${RESET}  ${CYAN}%s${RESET}" "${wave[*]}")")

            # Show response text synced to TTS sentence progress
            if [[ ${#tts_sentences[@]} -gt 0 ]]; then
                # Join revealed sentences
                visible_text="${tts_sentences[*]}"
                while IFS= read -r wline; do
                    lines+=("$(printf "  %s" "$wline")")
                done <<< "$(echo "$visible_text" | fold -s -w "$TEXT_WIDTH")"
            elif [[ -n "$response_text" ]]; then
                # No progress yet — show preview
                read -ra words <<< "$response_text"
                preview="${words[*]:0:3}..."
                lines+=("$(printf "  ${DIM}%s${RESET}" "$preview")")
            fi
            ;;
        LISTENING_FOLLOWUP)
            mic_frames=("●      " "●●     " "●●●    " "●●●●   " "●●●●●  " " ●●●●● " "  ●●●●●" "   ●●●●" "    ●●●" "     ●●" "      ●" "       ")
            idx=$(( frame % ${#mic_frames[@]} ))
            lines+=("$(printf "${GREEN}${BOLD} 󰍬 Follow-up?${RESET}")")
            lines+=("$(printf "  ${GREEN}%s${RESET}" "${mic_frames[$idx]}")")
            ;;
        *)
            lines+=("$(printf "${DIM} 󰍬 Dusky Voice${RESET}")")
            lines+=("$(printf "${DIM}  Ready${RESET}")")
            ;;
    esac

    # Determine which lines to show (scroll if needed)
    total=${#lines[@]}
    if (( total > ROWS )); then
        # Show the tail — auto-scroll to latest content
        start=$(( total - ROWS ))
    else
        start=0
    fi

    # Render frame: home cursor, draw visible lines, clear rest
    buf=""
    r=1
    for (( i=start; i<total && r<=ROWS; i++, r++ )); do
        buf+="\033[${r};1H${lines[$i]}\033[K"
    done
    # Clear remaining rows
    for (( ; r<=ROWS; r++ )); do
        buf+="\033[${r};1H\033[K"
    done
    printf "%b" "$buf"

    sleep 0.08
done
