#!/usr/bin/env bash
# Install whisper-dictation: dependencies, model, scripts, Hammerspoon hook.
# Safe to re-run; each step is skipped if already done.
set -euo pipefail

# --- Configuration (override via environment) ------------------------------
MODELS_DIR="${MODELS_DIR:-$HOME/.local/share/whisper-models}"
MODEL_NAME="${MODEL_NAME:-ggml-large-v3-turbo.bin}"
MODEL_URL="${MODEL_URL:-https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$MODEL_NAME}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
HS_DIR="${HS_DIR:-$HOME/.hammerspoon}"
# ---------------------------------------------------------------------------

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUIRE_LINE='require("whisper-dictation")'

say() { printf '==> %s\n' "$*"; }

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This tool is macOS-only (it uses Hammerspoon)." >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required: https://brew.sh" >&2
  exit 1
fi

# Dependencies
if command -v sox >/dev/null 2>&1; then say "sox already installed"
else say "Installing sox"; brew install sox; fi

if command -v whisper-cli >/dev/null 2>&1; then say "whisper-cpp already installed"
else say "Installing whisper-cpp"; brew install whisper-cpp; fi

if [ -d "/Applications/Hammerspoon.app" ] || brew list --cask hammerspoon >/dev/null 2>&1; then
  say "Hammerspoon already installed"
else
  say "Installing Hammerspoon"; brew install --cask hammerspoon
fi

# Model
mkdir -p "$MODELS_DIR"
if [ -s "$MODELS_DIR/$MODEL_NAME" ]; then
  say "Model already present: $MODELS_DIR/$MODEL_NAME"
else
  say "Downloading $MODEL_NAME (about 1.6 GB) to $MODELS_DIR"
  curl -fL --progress-bar -o "$MODELS_DIR/$MODEL_NAME.part" "$MODEL_URL"
  mv "$MODELS_DIR/$MODEL_NAME.part" "$MODELS_DIR/$MODEL_NAME"
fi

# Scripts
mkdir -p "$BIN_DIR" "$HS_DIR"
install -m 755 "$REPO_DIR/bin/ptt-dictate.sh" "$BIN_DIR/ptt-dictate.sh"
say "Installed $BIN_DIR/ptt-dictate.sh"
install -m 644 "$REPO_DIR/hammerspoon/whisper-dictation.lua" "$HS_DIR/whisper-dictation.lua"
say "Installed $HS_DIR/whisper-dictation.lua"

INIT="$HS_DIR/init.lua"
touch "$INIT"
if grep -qF "$REQUIRE_LINE" "$INIT"; then
  say "init.lua already loads whisper-dictation"
else
  printf '\n-- Local whisper push-to-talk dictation (hold right-cmd + right-option)\n%s\n' \
    "$REQUIRE_LINE" >>"$INIT"
  say "Added $REQUIRE_LINE to $INIT"
fi

# Non-default locations need matching edits in the installed files.
if [ "$MODELS_DIR/$MODEL_NAME" != "$HOME/.local/share/whisper-models/ggml-large-v3-turbo.bin" ]; then
  echo
  echo "Note: you used a non-default model path. Hammerspoon does not pass your"
  echo "shell environment to the script, so edit the MODEL= line in"
  echo "$BIN_DIR/ptt-dictate.sh to point at $MODELS_DIR/$MODEL_NAME."
fi
if [ "$BIN_DIR" != "$HOME/.local/bin" ]; then
  echo
  echo "Note: you used a non-default BIN_DIR. Edit the SCRIPT line in"
  echo "$HS_DIR/whisper-dictation.lua to point at $BIN_DIR/ptt-dictate.sh."
fi

cat <<'MSG'

Done. Remaining manual steps:
  1. Open Hammerspoon and choose "Reload Config" from its menu bar icon.
  2. System Settings > Privacy & Security > Accessibility: enable Hammerspoon
     (needed to read the hotkey and paste text).
  3. System Settings > Privacy & Security > Microphone: allow Hammerspoon
     (macOS asks the first time you dictate).
Then hold right-Command + right-Option, speak, and release.
MSG
