#!/usr/bin/env bash
# Voice assistant overlay — shows state + cava visualizer in a small terminal
# Spawned by the voice assistant daemon on wake, killed on idle

STATE_FILE="/tmp/dusky_voice_state.json"
CAVA_FIFO="/tmp/dusky_voice_cava"

# Colors (ANSI)
DIM='\033[2m'
BOLD='\033[1m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
WHITE='\033[37m'
RESET='\033[0m'

# Cava unicode bar chars
BARS=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)

cleanup() {
    [[ -v CAVA_PID ]] && kill "$CAVA_PID" 2>/dev/null
    rm -f "$CAVA_FIFO"
    exit 0
}
trap cleanup EXIT INT TERM

# Start cava outputting raw ASCII to a FIFO for us to read
rm -f "$CAVA_FIFO"
mkfifo "$CAVA_FIFO"

cava_config="[general]
bars = 12
framerate = 30

[input]
method = pulse
source = auto

[output]
method = raw
raw_target = $CAVA_FIFO
data_format = ascii
ascii_max_range = 7"

cava -p /dev/fd/3 3<<<"$cava_config" &>/dev/null &
CAVA_PID=$!

# Open FIFO for non-blocking reads
exec 4<"$CAVA_FIFO"

prev_state=""
cava_line=""
last_text=""

while true; do
    # Read latest cava output (non-blocking)
    if read -t 0.05 -r line <&4 2>/dev/null; then
        cava_line="$line"
    fi

    # Read state file
    if [[ -f "$STATE_FILE" ]]; then
        state=$(python3 -c "
import json, sys
try:
    d = json.load(open('$STATE_FILE'))
    print(d.get('state',''), d.get('text',''), d.get('user_text',''), sep='|||')
except: print('|||', sep='')
" 2>/dev/null)
        IFS='|||' read -r cur_state _ status_text _ user_text _ <<< "$state"
    else
        cur_state="IDLE"
        status_text=""
        user_text=""
    fi

    # Build cava bar display
    bar_display=""
    if [[ -n "$cava_line" ]]; then
        IFS=';' read -ra vals <<< "$cava_line"
        for v in "${vals[@]}"; do
            [[ -z "$v" ]] && continue
            idx=$((v > 7 ? 7 : (v < 0 ? 0 : v)))
            bar_display+="${BARS[$idx]}"
        done
    fi

    # Clear screen and draw
    printf '\033[2J\033[H'

    case "$cur_state" in
        WAKE_DETECTED)
            printf "${CYAN}${BOLD}  Wake Detected${RESET}\n"
            printf "${DIM}  Preparing...${RESET}\n"
            ;;
        RECORDING)
            printf "${GREEN}${BOLD}  Listening...${RESET}\n"
            # Show a simple pulsing mic indicator
            t=$(( $(date +%s%N | cut -c1-13) / 500 % 4 ))
            dots=""
            for ((i=0; i<t; i++)); do dots+="●"; done
            printf "${GREEN}  ${dots}${RESET}\n"
            ;;
        TRANSCRIBING)
            printf "${YELLOW}${BOLD}  Transcribing...${RESET}\n"
            [[ -n "$user_text" ]] && printf "${DIM}  \"${user_text:0:40}\"${RESET}\n"
            ;;
        THINKING)
            printf "${MAGENTA}${BOLD}  Thinking...${RESET}\n"
            [[ -n "$user_text" ]] && printf "${DIM}  \"${user_text:0:40}\"${RESET}\n"
            ;;
        SPEAKING)
            printf "${CYAN}${BOLD}  Speaking${RESET}\n"
            # Show cava bars when speaking
            if [[ -n "$bar_display" ]]; then
                printf "  ${CYAN}${bar_display}${RESET}\n"
            else
                printf "  ${DIM}...${RESET}\n"
            fi
            ;;
        LISTENING_FOLLOWUP)
            printf "${GREEN}${BOLD}  Follow-up?${RESET}\n"
            printf "${DIM}  Listening...${RESET}\n"
            ;;
        *)
            # IDLE or unknown — overlay should be killed, but just in case
            printf "${DIM}  Dusky Voice${RESET}\n"
            printf "${DIM}  Ready${RESET}\n"
            ;;
    esac

    sleep 0.1
done
