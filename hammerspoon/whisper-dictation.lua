-- Push-to-talk dictation via local whisper.cpp.
-- Hold right-cmd + right-option, speak, release. Text is pasted into the
-- focused app. Nothing leaves the machine.

local M = {}

local SCRIPT = os.getenv("HOME") .. "/.local/bin/ptt-dictate.sh"

-- Device-dependent modifier bits from IOLLEvent.h. hs.eventtap's getFlags()
-- only reports "cmd"/"alt" without saying which side, so we read the raw
-- CGEvent flags to tell right-hand keys from left.
local NX_DEVICERCMDKEYMASK = 0x10
local NX_DEVICERALTKEYMASK = 0x40

local recording = false
local listeningAlert = nil

-- Works for single-bit masks without needing Lua 5.3+ bitwise operators.
local function hasBit(value, mask)
  return (math.floor(value / mask) % 2) == 1
end

local function startRecording()
  if recording then return end
  recording = true
  listeningAlert = hs.alert.show("🎤 Listening…", hs.alert.defaultStyle,
                                 hs.screen.mainScreen(), "infinite")
  hs.task.new(SCRIPT, nil, { "start" }):start()
end

local function stopRecording()
  if not recording then return end
  recording = false
  if listeningAlert then
    hs.alert.closeSpecific(listeningAlert)
    listeningAlert = nil
  end

  local thinking = hs.alert.show("✍️  transcribing…", hs.alert.defaultStyle,
                                 hs.screen.mainScreen(), "infinite")

  hs.task.new(SCRIPT, function(exitCode, stdout, _stderr)
    hs.alert.closeSpecific(thinking)
    local text = (stdout or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if exitCode ~= 0 or text == "" then
      hs.alert.show("no speech detected")
      return
    end
    -- Paste via the clipboard (fast and reliable), then put back whatever
    -- the user had copied so dictating doesn't eat their clipboard.
    local saved = hs.pasteboard.getContents()
    hs.pasteboard.setContents(text)
    hs.eventtap.keyStroke({ "cmd" }, "v")
    hs.timer.doAfter(0.4, function()
      if saved then hs.pasteboard.setContents(saved) end
    end)
  end, { "stop" }):start()
end

-- A config reload can leave the previous eventtap alive until GC, giving two
-- taps with separate `recording` flags (double start, double paste). Stop the
-- old one explicitly before creating ours.
if _G.__whisperDictationTap then _G.__whisperDictationTap:stop() end

-- Held as a module field so Lua's GC doesn't collect the live eventtap.
M.tap =hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, function(event)
  local raw = event:getRawEventData().CGEventData.flags
  local bothDown = hasBit(raw, NX_DEVICERCMDKEYMASK) and hasBit(raw, NX_DEVICERALTKEYMASK)

  if bothDown then
    startRecording()
  elseif recording then
    -- Either key released: that's the end of the utterance.
    stopRecording()
  end
  return false -- never swallow the event; other shortcuts still work
end)

M.tap:start()
_G.__whisperDictationTap = M.tap

return M
