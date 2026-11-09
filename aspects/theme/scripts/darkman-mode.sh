#!/usr/bin/env bash
# darkman mode-change script. Installed under $XDG_DATA_DIRS/darkman/ so
# darkman invokes it with a single argument: "dark" or "light".
#
# darkman writes its own cache at ~/.cache/darkman/mode.txt, but AGENT.md
# mandates ~/.local/state/darkman/theme-mode as the SINGLE source of truth.
# We copy the mode into that file, then delegate to update-theme (which
# regenerates colors.* if missing) and reshuffle the wallpaper for the mode.
set -o errexit
set -o nounset
set -o pipefail

HOME_DIR="/home/dark_eremite"
STATE_DIR="$HOME_DIR/.local/state/darkman"
STATE="$STATE_DIR/theme-mode"

MODE="${1:-auto}"
case "$MODE" in
  dark|light) ;;
  *) MODE="auto" ;;
esac

mkdir -p "$STATE_DIR"
printf '%s' "$MODE" > "$STATE"

# Let the wallpaper + palette follow the new mode, then reload both clients.
random-wallpaper
