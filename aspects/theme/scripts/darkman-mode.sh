#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

HOME_DIR="${HOME:?HOME is not set}"
STATE_DIR="$HOME_DIR/.local/state/darkman"
STATE="$STATE_DIR/theme-mode"

MODE="${1:-}"
case "$MODE" in
  dark|light) ;;
  *) exit 0 ;;
esac

mkdir -p "$STATE_DIR"
printf '%s' "$MODE" > "$STATE"

random-wallpaper
