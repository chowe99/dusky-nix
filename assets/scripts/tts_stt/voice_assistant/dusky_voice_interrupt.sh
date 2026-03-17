#!/usr/bin/env bash
# Interrupt voice assistant — first press stops TTS, second press stops recording
PID_FILE="/tmp/dusky_voice_assistant.pid"
FIFO_PATH="/tmp/dusky_voice_assistant.fifo"

# First: try to kill TTS playback
if pgrep -f "mpv.*demuxer-rawaudio" >/dev/null 2>&1; then
    pkill -f "mpv.*demuxer-rawaudio" 2>/dev/null
    exit 0
fi

# Second: no TTS running, kill recording and end conversation
pkill -f "pw-record.*voice" 2>/dev/null || true
pkill -f "pw-record.*followup" 2>/dev/null || true

is_running() {
  [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null
}

if is_running; then
  printf 'INTERRUPT\n' > "$FIFO_PATH" &
  WRITE_PID=$!
  for _ in $(seq 1 20); do
    if ! kill -0 "$WRITE_PID" 2>/dev/null; then
      wait "$WRITE_PID" 2>/dev/null
      break
    fi
    sleep 0.1
  done
  kill "$WRITE_PID" 2>/dev/null || true
fi
