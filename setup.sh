#!/usr/bin/env bash
#
# setup.sh - make the Copilot key play a random Flowery voiceline.
#
# Self-contained setup for Arch-based systems. It:
#   * installs keyd (and a sound player) if needed,
#   * downloads the Flowery voicelines pack into ./sounds,
#   * maps the Copilot key to ./player.sh through keyd.
#
# Safe to re-run (idempotent). See --help.
#
set -euo pipefail

PROJECT_DIR="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")"
PLAYER="$PROJECT_DIR/player.sh"
DEFAULT_SOUND_DIR="$PROJECT_DIR/sounds"
SOUND_DIR="$DEFAULT_SOUND_DIR"
SOUND_DIR_FILE="$PROJECT_DIR/sound-dir"
KEYD_CONF="/etc/keyd/copilot.conf"
PACK_URL="https://pub-d3643445511f4a59b7c1923785cafa51.r2.dev/mods/voice/flowery-voicelines-pack-697165/download/flowery-voicelines-pack-697165.zip"
DETECT_SECS="${DETECT_SECS:-15}"

if [[ -t 1 ]]; then
    BOLD=$'\e[1m'; RED=$'\e[31m'; GRN=$'\e[32m'; YEL=$'\e[33m'; RST=$'\e[0m'
else
    BOLD=; RED=; GRN=; YEL=; RST=
fi
info() { printf '%s[*]%s %s\n' "$GRN" "$RST" "$*"; }
warn() { printf '%s[!]%s %s\n' "$YEL" "$RST" "$*"; }
ok()   { printf '%s[+]%s %s\n' "$GRN" "$RST" "$*"; }
die()  { printf '%s[x]%s %s\n' "$RED" "$RST" "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Usage: ./setup.sh [options]

Options:
  --dir DIR       Use DIR as the sound folder instead of ./sounds
  --device ID     Skip key detection; use this keyd device id
  --chord CHORD   Skip key detection; use this keyd chord
  --force         Re-download / re-extract the sound pack
  --no-download   Do not download the sound pack
  --uninstall     Remove the keyd mapping and reload keyd
  -h, --help      Show this help
EOF
}

CUSTOM_DIR=""
DEVICE=""
CHORD=""
FORCE=0
DO_DOWNLOAD=1
DO_UNINSTALL=0

while (($#)); do
    case "$1" in
        --dir)         CUSTOM_DIR="$2"; shift 2 ;;
        --dir=*)       CUSTOM_DIR="${1#*=}"; shift ;;
        --device)      DEVICE="$2"; shift 2 ;;
        --device=*)    DEVICE="${1#*=}"; shift ;;
        --chord)       CHORD="$2"; shift 2 ;;
        --chord=*)     CHORD="${1#*=}"; shift ;;
        --force)       FORCE=1; shift ;;
        --no-download) DO_DOWNLOAD=0; shift ;;
        --uninstall)   DO_UNINSTALL=1; shift ;;
        -h|--help)     usage; exit 0 ;;
        *)             echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

audio_find() {
    find "$1" -type f \
        \( -iname '*.wav' -o -iname '*.mp3'  -o -iname '*.ogg'  -o -iname '*.oga' \
        -o -iname '*.flac' -o -iname '*.m4a' -o -iname '*.opus' -o -iname '*.aac' \) \
        2>/dev/null
}
has_audio() { local d="$1"; [[ -d "$d" ]] && [[ -n "$(audio_find "$d" | head -n1)" ]]; }

# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------
[[ $EUID -ne 0 ]] || die "Run this as your normal user (the script calls sudo itself)."
command -v pacman >/dev/null 2>&1 || die "pacman not found - this targets Arch-based systems."
command -v sudo   >/dev/null 2>&1 || die "sudo not found."

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------
if (( DO_UNINSTALL )); then
    info "Removing Copilot key mapping ($KEYD_CONF)..."
    sudo rm -f "$KEYD_CONF"
    sudo keyd reload 2>/dev/null || true
    ok "Removed. (Project files and the keyd package were left intact.)"
    exit 0
fi

# ---------------------------------------------------------------------------
# Custom sound dir
# ---------------------------------------------------------------------------
if [[ -n "$CUSTOM_DIR" ]]; then
    CUSTOM_DIR="$(readlink -f "$CUSTOM_DIR")"
    [[ -d "$CUSTOM_DIR" ]] || die "Sound dir not found: $CUSTOM_DIR"
    printf '%s\n' "$CUSTOM_DIR" > "$SOUND_DIR_FILE"
    SOUND_DIR="$CUSTOM_DIR"
    DO_DOWNLOAD=0
    ok "Using custom sound dir: $SOUND_DIR"
fi

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------
pkgs=()
pacman -Qq keyd >/dev/null 2>&1 || pkgs+=(keyd)
command -v curl >/dev/null 2>&1 || pkgs+=(curl)
if ! command -v pw-play >/dev/null 2>&1 && ! command -v paplay >/dev/null 2>&1; then
    if pacman -Qq pipewire >/dev/null 2>&1; then
        pkgs+=(pipewire-audio)
    fi
fi
if ((${#pkgs[@]})); then
    info "Installing: ${pkgs[*]}"
    sudo pacman -S --needed --noconfirm "${pkgs[@]}"
fi
sudo systemctl enable --now keyd

# ---------------------------------------------------------------------------
# Download + extract the sound pack
# ---------------------------------------------------------------------------
if (( DO_DOWNLOAD )); then
    if (( FORCE )) || ! has_audio "$SOUND_DIR"; then
        mkdir -p "$SOUND_DIR"
        tmpzip="$(mktemp "$PROJECT_DIR/.pack.XXXXXX.zip")"
        info "Downloading Flowery voicelines pack (~11 MB)..."
        curl -fL --retry 3 -o "$tmpzip" "$PACK_URL"
        info "Extracting into $SOUND_DIR ..."
        if command -v bsdtar >/dev/null 2>&1; then
            bsdtar -xf "$tmpzip" -C "$SOUND_DIR"
        elif command -v unzip >/dev/null 2>&1; then
            unzip -q -o "$tmpzip" -d "$SOUND_DIR"
        else
            python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' \
                "$tmpzip" "$SOUND_DIR"
        fi
        rm -f "$tmpzip"
        ok "Sound pack ready: $(audio_find "$SOUND_DIR" | wc -l) audio files."
    else
        info "Sounds already present in $SOUND_DIR (use --force to re-download)."
    fi
fi

# ---------------------------------------------------------------------------
# Detect the Copilot key
# ---------------------------------------------------------------------------
if [[ -z "$DEVICE" || -z "$CHORD" ]]; then
    info "Get ready to press the Copilot key once."
    sudo -v || die "sudo authentication failed."
    for i in 5 4 3 2 1; do printf '\r  Starting in %s...   ' "$i"; sleep 1; done
    printf '\r  %s>>> PRESS THE COPILOT KEY NOW <<<%s          \n' "$BOLD" "$RST"

    raw="$(timeout "$DETECT_SECS" sudo keyd monitor 2>/dev/null || true)"

    # Collect every key held in the first press burst (before the first
    # release) and emit "<device id><TAB><key+key+key>".
    parsed="$(printf '%s\n' "$raw" | awk -F'\t' '
        NF >= 3 && $3 ~ / down$/ {
            if (done) next
            if (id == "") id = $2
            if ($2 != id) next
            k = $3; sub(/ down$/, "", k)
            if (!(k in seen)) { seen[k] = 1; keys[++n] = k }
            next
        }
        NF >= 3 && $3 ~ / up$/ { done = 1 }
        END {
            if (n == 0) exit 1
            chord = keys[1]
            for (i = 2; i <= n; i++) chord = chord "+" keys[i]
            print id "\t" chord
        }
    ' || true)"

    if [[ -n "$parsed" ]]; then
        [[ -z "$DEVICE" ]] && DEVICE="${parsed%%$'\t'*}"
        [[ -z "$CHORD"  ]] && CHORD="${parsed#*$'\t'}"
        ok "Detected device '$DEVICE', chord '$CHORD'."
    else
        warn "Auto-detection failed."
        warn "Run 'sudo keyd monitor', press the key, then re-run with --device and --chord."
    fi
fi
[[ -n "$DEVICE" ]] || die "No device id available (use --device)."
[[ -n "$CHORD"  ]] || CHORD="leftmeta+leftshift+f23"

# ---------------------------------------------------------------------------
# Write the keyd mapping and reload
# ---------------------------------------------------------------------------
info "Writing $KEYD_CONF"
sudo mkdir -p /etc/keyd
printf '[ids]\n%s\n\n[main]\n%s = command(runuser -u %s -- %q)\n' \
    "$DEVICE" "$CHORD" "$USER" "$PLAYER" | sudo tee "$KEYD_CONF" >/dev/null
sudo keyd check "$KEYD_CONF" >/dev/null || die "keyd config failed validation."
sudo keyd reload
ok "keyd reloaded."

# ---------------------------------------------------------------------------
# Test
# ---------------------------------------------------------------------------
info "Testing: you should hear a random voiceline..."
"$PLAYER" || warn "Nothing played (is the sound folder empty?)."

cat <<EOF

${BOLD}Done!${RST}  Press the Copilot key to play a random voiceline.

  Copilot key mapping : $KEYD_CONF
  Player              : $PLAYER
  Sounds              : $SOUND_DIR

  Edit mapping        : sudo nano $KEYD_CONF && sudo keyd reload
  Change behaviour    : $PLAYER
  Remove key mapping  : $PROJECT_DIR/setup.sh --uninstall
EOF
