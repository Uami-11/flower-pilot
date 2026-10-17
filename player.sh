#!/usr/bin/env bash
#
# player.sh - play a random sound for the Copilot key.
#
# Invoked by keyd (as root, via `runuser`), so it must:
#   * locate its own project directory (even when called by absolute path),
#   * reach the user's audio session (XDG_RUNTIME_DIR / DBus).
#
# Sound source priority:
#   1. $COPILOT_SOUND_DIR
#   2. the project's ./sound-dir file (one path)
#   3. the project's ./sounds directory
#   4. fallback: the Soundux library (~/.config/Soundux/config.json)
#
set -euo pipefail

# Resolve our real location so `./sounds` works regardless of how we're called.
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
PROJECT_DIR="$(dirname "$SELF")"

# Reach the user's audio session even when keyd runs us as root.
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"
export HOME="${HOME:-$(getent passwd "$(id -u)" | cut -d: -f6)}"

# Debounce: ignore repeat triggers within 400ms (guards chord edge cases).
LOCK="${XDG_RUNTIME_DIR}/flower-pilot.lock"
now=$(date +%s%3N)
last=$(cat "$LOCK" 2>/dev/null || echo 0)
if (( now - last < 400 )); then exit 0; fi
printf '%s' "$now" > "$LOCK" 2>/dev/null || true

# Determine the sound directory.
SOUND_DIR="${COPILOT_SOUND_DIR:-}"
if [[ -z "$SOUND_DIR" && -f "$PROJECT_DIR/sound-dir" ]]; then
    SOUND_DIR="$(head -n1 "$PROJECT_DIR/sound-dir")"
fi
[[ -n "$SOUND_DIR" ]] || SOUND_DIR="$PROJECT_DIR/sounds"
export SOUND_DIR

# Pick a random sound.
sound="$(python3 - <<'PY'
import json, os, random, sys

def folder_sounds(d):
    d = os.path.expanduser(d)
    if not d or not os.path.isdir(d):
        return []
    exts = {".wav", ".mp3", ".ogg", ".oga", ".flac", ".m4a",
            ".opus", ".aac", ".wma", ".aiff", ".aif"}
    found = []
    for root, _dirs, files in os.walk(d):
        for name in files:
            if os.path.splitext(name)[1].lower() in exts:
                found.append(os.path.join(root, name))
    return found

def soundux_sounds():
    cfg = os.path.expanduser("~/.config/Soundux/config.json")
    if not os.path.isfile(cfg):
        return []
    try:
        with open(cfg, encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        return []
    found = []
    for tab in data.get("data", {}).get("tabs", []):
        for snd in tab.get("sounds", []) or []:
            p = snd.get("path")
            if not p:
                continue
            p = os.path.expanduser(p)
            if os.path.isfile(p):
                found.append(p)
    return found

sounds = folder_sounds(os.environ.get("SOUND_DIR", "")) or soundux_sounds()
if not sounds:
    sys.exit(3)
print(random.choice(sounds))
PY
)" || exit 0

# Play it. Overlapping is allowed: one player process per press.
if command -v pw-play >/dev/null 2>&1; then
    pw-play "$sound" >/dev/null 2>&1 &
elif command -v paplay >/dev/null 2>&1; then
    paplay "$sound" >/dev/null 2>&1 &
elif command -v ffplay >/dev/null 2>&1; then
    ffplay -nodisp -autoexit -loglevel quiet "$sound" >/dev/null 2>&1 &
fi
exit 0
