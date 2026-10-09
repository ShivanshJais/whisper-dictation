#!/usr/bin/env bash
# Push-to-talk dictation: record mic -> whisper.cpp -> stdout.
# Usage: ptt-dictate.sh start   (begins recording)
#        ptt-dictate.sh stop    (ends recording, transcribes, prints text)
# Pipe to pbcopy for standalone use; Hammerspoon reads stdout directly.
set -uo pipefail

# Hammerspoon launches tasks with a minimal PATH, so be explicit.
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

MODEL="${WHISPER_PTT_MODEL:-$HOME/.local/share/whisper-models/ggml-large-v3-turbo.bin}"
WAV="/tmp/whisper-ptt.wav"
PIDFILE="/tmp/whisper-ptt.pid"
LOG="/tmp/whisper-ptt.log"

log() { echo "[$(date +%H:%M:%S)] $*" >>"$LOG"; }

case "${1:-}" in
  start)
    # Kill any stale recorder first. Match on the command line, not just the
    # pidfile: two overlapping starts can overwrite each other's pidfile and
    # orphan a sox that then records forever.
    [ -f "$PIDFILE" ] && kill "$(cat "$PIDFILE")" 2>/dev/null
    pkill -INT -f "sox .*$WAV" 2>/dev/null
    rm -f "$WAV" "$PIDFILE"
    # 16 kHz mono 16-bit: exactly whisper's native format, so no resampling.
    sox -d -q -r 16000 -c 1 -b 16 -e signed-integer -t wav "$WAV" >>"$LOG" 2>&1 &
    echo $! >"$PIDFILE"
    log "start pid=$(cat "$PIDFILE")"
    ;;

  stop)
    [ -f "$PIDFILE" ] || { log "stop: no active recording"; exit 0; }
    PID="$(cat "$PIDFILE")"
    rm -f "$PIDFILE"
    # SIGINT, not SIGTERM: sox handles INT gracefully and fixes up the WAV
    # header length on its way out. SIGTERM can leave a truncated header.
    kill -INT "$PID" 2>/dev/null
    for _ in $(seq 1 40); do kill -0 "$PID" 2>/dev/null || break; sleep 0.05; done
    # Never leave any recorder running after a stop, even one whose pid was lost.
    pkill -INT -f "sox .*$WAV" 2>/dev/null

    [ -s "$WAV" ] || { log "stop: no audio captured"; exit 0; }
    # Ignore trigger-happy taps; under ~0.4s there's nothing to transcribe.
    DUR="$(sox --i -D "$WAV" 2>/dev/null || echo 0)"
    if awk -v d="$DUR" 'BEGIN{exit !(d < 0.4)}'; then log "stop: too short (${DUR}s)"; exit 0; fi

    TEXT="$(whisper-cli -m "$MODEL" -f "$WAV" -l en -nt -np 2>>"$LOG" \
            | tr '\n' ' ' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/  */ /g')"
    log "stop: ${DUR}s -> '$TEXT'"
    [ -n "$TEXT" ] || exit 0
    printf '%s' "$TEXT"
    ;;

  *)
    echo "usage: $(basename "$0") {start|stop}" >&2; exit 2 ;;
esac
