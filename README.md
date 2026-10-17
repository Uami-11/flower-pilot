# flower-pilot

Turn the useless **Copilot key** on a laptop keyboard into a **random Flowery
voiceline** button.

Pressing the key plays a random clip from the Flowery voicelines pack through
your normal audio output. The key's original behaviour (a bogus
`Meta+Shift+F23` combo) is fully swallowed by [keyd], so nothing leaks to the
compositor or applications.

## How it works

```
Copilot key ──▶ keyd (matches Meta+Shift+F23) ──▶ player.sh
                                                    │
                                   random file from ./sounds
                                                    │
                                              pw-play (default output)
```

## Requirements

* An **Arch-based** system with `pacman`
* `sudo` (for installing keyd and writing `/etc/keyd/copilot.conf`)
* PipeWire or PulseAudio (`pw-play` / `paplay`)

## Usage

```bash
./setup.sh
```

That will:

1. install `keyd` (and a player) if missing,
2. download + extract the Flowery voicelines pack into `./sounds`,
3. ask you to press the Copilot key once so it can detect the device/chord,
4. map the key to `./player.sh` via keyd and reload,
5. play one clip to test.

Re-running is safe. Options:

| Option | Description |
| --- | --- |
| `--dir DIR` | Use `DIR` as the sound folder instead of `./sounds` |
| `--device ID` | Skip detection; use this keyd device id |
| `--chord CHORD` | Skip detection; use this keyd chord |
| `--force` | Re-download / re-extract the pack |
| `--no-download` | Only configure the key (no download) |
| `--uninstall` | Remove the keyd mapping and reload |

## Files

| File | Purpose |
| --- | --- |
| `setup.sh` | One-shot installer (Arch) |
| `player.sh` | Plays a random sound; called by keyd |
| `sounds/` | The extracted voicelines pack |
| `sound-dir` | Optional: overrides the sound folder (from `--dir`) |

## Notes

* The player falls back to the Soundux library (`~/.config/Soundux/config.json`)
  if `./sounds` is empty, so it still works without the download.
* Pressing the key repeatedly overlaps sounds (one player per press), with a
  400 ms debounce to avoid double-firing.
* If something goes wrong with keyd, the emergency exit sequence is
  `Backspace + Escape + Enter`.

[keyd]: https://github.com/rvaiya/keyd
