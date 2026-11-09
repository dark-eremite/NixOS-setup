#!/usr/bin/env bash
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

random-wallpaper
