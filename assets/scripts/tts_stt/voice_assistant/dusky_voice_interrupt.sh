#!/usr/bin/env bash
# SUPER+Esc for the voice assistant:
#   single tap  -> PROCEED: stop listening now, transcribe what's captured, keep the turn going
#                  (rescues a noisy room where silence detection never trips)
#   double tap  -> full interrupt: kill TTS + recording and abort the turn (the old behavior)
# The first tap fires PROCEED immediately (no lag); a second tap within the window escalates.
PID_FILE="/tmp/dusky_voice_assistant.pid"
FIFO_PATH="/tmp/dusky_voice_assistant.fifo"
STAMP="/tmp/dusky_voice_esc_stamp"
WINDOW_MS=600

is_running() { [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; }

now=$(date +%s%3N)
last=$(cat "$STAMP" 2>/dev/null || echo 0)
[[ "$last" =~ ^[0-9]+$ ]] || last=0
printf '%s' "$now" > "$STAMP"

if (( now - last <= WINDOW_MS )); then
  # Double tap: full stop. Kill playback/recording here, then abort the turn.
  pkill -f "mpv.*demuxer-rawaudio" 2>/dev/null || true
  pkill -f "pw-record.*voice" 2>/dev/null || true
  pkill -f "pw-record.*followup" 2>/dev/null || true
  CMD=INTERRUPT
else
  # Single tap: stop listening, proceed to the next phase (transcribe → think → speak).
  CMD=PROCEED
fi

is_running || exit 0

printf '%s\n' "$CMD" > "$FIFO_PATH" &
WRITE_PID=$!
for _ in $(seq 1 20); do
  kill -0 "$WRITE_PID" 2>/dev/null || { wait "$WRITE_PID" 2>/dev/null; break; }
  sleep 0.1
done
kill "$WRITE_PID" 2>/dev/null || true
