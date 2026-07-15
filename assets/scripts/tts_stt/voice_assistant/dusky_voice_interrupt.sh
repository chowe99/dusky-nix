#!/usr/bin/env bash
# Cancel the voice assistant pipeline at ANY phase (listening, thinking, speaking).
PID_FILE="/tmp/dusky_voice_assistant.pid"
FIFO_PATH="/tmp/dusky_voice_assistant.fifo"

# Stop TTS playback and any active recording immediately.
pkill -f "mpv.*demuxer-rawaudio" 2>/dev/null || true
pkill -f "pw-record.*voice" 2>/dev/null || true
pkill -f "pw-record.*followup" 2>/dev/null || true

# Signal the daemon to abort the current turn — this covers the THINKING phase,
# where nothing is playing/recording but the LLM/web-search request is in flight.
is_running() { [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; }
if is_running; then
  printf 'INTERRUPT\n' > "$FIFO_PATH" &
  WRITE_PID=$!
  for _ in $(seq 1 20); do
    kill -0 "$WRITE_PID" 2>/dev/null || { wait "$WRITE_PID" 2>/dev/null; break; }
    sleep 0.1
  done
  kill "$WRITE_PID" 2>/dev/null || true
fi
