PID_FILE="/tmp/dusky_voice_assistant.pid"
FIFO_PATH="/tmp/dusky_voice_assistant.fifo"

is_running() {
  [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null
}

if ! is_running; then
  notify-send -a "Dusky Voice" -t 2000 "Not Running" "Voice assistant is not active"
  exit 0
fi

printf 'RESET\n' > "$FIFO_PATH" &
WRITE_PID=$!

# Wait up to 2s for FIFO write
WRITE_OK=false
for _ in $(seq 1 20); do
  if ! kill -0 "$WRITE_PID" 2>/dev/null; then
    wait "$WRITE_PID" 2>/dev/null && WRITE_OK=true
    break
  fi
  sleep 0.1
done

if ! $WRITE_OK; then
  kill "$WRITE_PID" 2>/dev/null || true
  notify-send -a "Dusky Voice" -u critical "Error" "Daemon unresponsive"
fi
