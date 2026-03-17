#!/usr/bin/env bash
# Interrupt TTS playback — kills MPV and sends INTERRUPT to daemon FIFO
PID_FILE="/tmp/dusky_voice_assistant.pid"
FIFO_PATH="/tmp/dusky_voice_assistant.fifo"

# Kill MPV TTS immediately for instant silence
pkill -f "mpv.*demuxer-rawaudio" 2>/dev/null || true

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
