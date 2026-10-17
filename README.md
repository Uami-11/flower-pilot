# flower-pilot

<img width="220" height="208" alt="flowery-flowery-deltarune" src="https://github.com/user-attachments/assets/252d259d-4d8e-4f4a-9cd4-b67af76c6744" />


Turn the useless **Copilot key** on a laptop keyboard into a **random Flowery
voiceline** button.

## Requirements

- An **Arch-based** system with `pacman`
- `sudo` (for installing keyd and writing `/etc/keyd/copilot.conf`)
- PipeWire or PulseAudio (`pw-play` / `paplay`)

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

| Option          | Description                                         |
| --------------- | --------------------------------------------------- |
| `--dir DIR`     | Use `DIR` as the sound folder instead of `./sounds` |
| `--device ID`   | Skip detection; use this keyd device id             |
| `--chord CHORD` | Skip detection; use this keyd chord                 |
| `--force`       | Re-download / re-extract the pack                   |
| `--no-download` | Only configure the key (no download)                |
| `--uninstall`   | Remove the keyd mapping and reload                  |
