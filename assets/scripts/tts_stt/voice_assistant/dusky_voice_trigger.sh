PID_FILE="/tmp/dusky_voice_assistant.pid"
READY_FILE="/tmp/dusky_voice_assistant.ready"
FIFO_PATH="/tmp/dusky_voice_assistant.fifo"

is_running() {
  [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null
}

case "${1:-}" in
  --kill)
    if is_running; then
      kill "$(cat "$PID_FILE")" 2>/dev/null || true
      echo "Daemon stopped."
    fi
    rm -f "$PID_FILE" "$FIFO_PATH" "$READY_FILE"
    exit 0 ;;
  --status)
    if is_running; then echo "Running (PID: $(cat "$PID_FILE"))"; else echo "Not running"; fi
    exit 0 ;;
  --restart)
    is_running && kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE" "$FIFO_PATH" "$READY_FILE"
    systemctl --user restart dusky-voice-assistant.service 2>/dev/null || dusky-voice-assistant-daemon &
    exit 0 ;;
  --activate)
    # Manual activation (skip wake word, start listening immediately)
    ;;
esac

# Start daemon if not running
if ! is_running; then
  rm -f "$PID_FILE" "$FIFO_PATH" "$READY_FILE"
  systemctl --user start dusky-voice-assistant.service 2>/dev/null || dusky-voice-assistant-daemon &
  # Wait for ready (30s timeout)
  for _ in $(seq 1 300); do
    [[ -f "$READY_FILE" ]] && break
    sleep 0.1
  done
  if [[ ! -f "$READY_FILE" ]]; then
    notify-send -a "Dusky Voice" -u critical "Startup Failed" "Daemon not ready after 30s"
    exit 1
  fi
fi

# Send command to FIFO
if [[ "${1:-}" == "--activate" ]]; then
  printf 'ACTIVATE\n' > "$FIFO_PATH" &
  WRITE_PID=$!
else
  printf 'TOGGLE\n' > "$FIFO_PATH" &
  WRITE_PID=$!
fi

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
