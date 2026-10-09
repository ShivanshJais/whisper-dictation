# whisper-dictation

Push-to-talk dictation for macOS that runs entirely on your machine. Hold
right-Command + right-Option, speak, let go, and the text is typed into
whatever app has focus. Transcription uses [whisper.cpp](https://github.com/ggerganov/whisper.cpp)
with the large-v3-turbo model; no audio or text is sent anywhere.

## Why

I fractured a bone near my wrist and typing became slow and painful. The
built-in options either send audio to a server or were not accurate enough
for technical writing, so I put together a small push-to-talk setup on top of
whisper.cpp that keeps everything local.

## Features

- Hold-to-talk hotkey (right-Command + right-Option) that works in any app
- On-device transcription with whisper.cpp large-v3-turbo
- Pastes the result into the focused app, then restores your clipboard
- Ignores accidental taps shorter than about 0.4 seconds
- Cleans up orphaned recorders so the microphone is never left running
- Other shortcuts keep working; the hotkey listener never swallows key events

## Requirements

- macOS (Apple Silicon recommended for transcription speed)
- [Homebrew](https://brew.sh)
- About 1.6 GB of disk space for the model

`setup.sh` installs the rest: `sox`, `whisper-cpp` and Hammerspoon.

## Install

```bash
git clone https://github.com/ShivanshJais/whisper-dictation.git
cd whisper-dictation
./setup.sh
```

The script is safe to re-run. It installs missing dependencies, downloads the
model if it is not already there, copies `ptt-dictate.sh` to `~/.local/bin`
and `whisper-dictation.lua` to `~/.hammerspoon`, and adds
`require("whisper-dictation")` to `~/.hammerspoon/init.lua` if it is missing.

Then reload the Hammerspoon config and grant permissions (see Troubleshooting).

## Usage

1. Click into any text field.
2. Hold right-Command + right-Option. A "Listening" alert appears.
3. Speak, then release either key.
4. After a short "transcribing" alert, the text is pasted.

The shell script also works on its own:

```bash
ptt-dictate.sh start
# speak
ptt-dictate.sh stop | pbcopy
```

## Configuration

`setup.sh` reads these environment variables:

| Variable     | Default                                  |
|--------------|------------------------------------------|
| `MODELS_DIR` | `~/.local/share/whisper-models`          |
| `MODEL_NAME` | `ggml-large-v3-turbo.bin`                |
| `MODEL_URL`  | Hugging Face `ggerganov/whisper.cpp` URL |
| `BIN_DIR`    | `~/.local/bin`                           |
| `HS_DIR`     | `~/.hammerspoon`                         |

At runtime, `ptt-dictate.sh` uses `WHISPER_PTT_MODEL` if set, otherwise the
default model path above. Hammerspoon does not pass your shell environment
to the script, so if you keep the model elsewhere, edit the `MODEL=` line in
the installed script. The script location is set by `SCRIPT` at the top of
`whisper-dictation.lua`, and the language (`-l en`) is on the `whisper-cli`
line in `ptt-dictate.sh`.

Temporary files live in `/tmp` (`whisper-ptt.wav`, `.pid`, `.log`). The log
contains your transcripts; delete it if that matters to you.

## How it works

- Hammerspoon watches modifier-key events and reads the raw device flags to
  tell the right-hand Command and Option keys from the left ones.
- When both are held, it runs `ptt-dictate.sh start`, which records 16 kHz
  mono audio with `sox`, the format whisper expects, so nothing is resampled.
- On release, `ptt-dictate.sh stop` sends SIGINT to `sox` so the WAV header is
  finalised, then runs `whisper-cli` on the file and prints the text.
- Hammerspoon saves the clipboard, pastes the text with Command-V, and puts
  the old clipboard back.

## Troubleshooting

- **Nothing happens on the hotkey:** enable Hammerspoon under System Settings >
  Privacy & Security > Accessibility, then reload the config.
- **"no speech detected" every time:** allow Hammerspoon under Privacy &
  Security > Microphone. Check `/tmp/whisper-ptt.log` for `sox` errors.
- **Command not found errors in the log:** the script adds `/opt/homebrew/bin`
  to `PATH`. On an Intel Mac, Homebrew lives in `/usr/local/bin`; add it to
  the `export PATH=` line in `ptt-dictate.sh`.
- **First transcription is slow:** the model is loaded from disk on each run;
  later runs are faster once the file is in the OS cache.

## License

MIT, see [LICENSE](LICENSE).
