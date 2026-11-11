#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

HOME_DIR="/home/dark_eremite"
STATE="$HOME_DIR/.local/state/darkman/theme-mode"
WALL_LINK="$HOME_DIR/.wallpapers/current"
STAMP="$HOME_DIR/.local/state/darkman/theme-source"
MATUGEN_CONFIG="@MATUGEN_CONFIG@"

@WALLPAPER_MODE@

mkdir -p "$HOME_DIR/.wallpapers/light" "$HOME_DIR/.wallpapers/dark" "$HOME_DIR/.local/state/darkman"

MODE="$(cat "$STATE" 2>/dev/null || echo auto)"
case "$MODE" in
  dark)  pool=( "$HOME_DIR"/.wallpapers/dark/* ) ;;
  light) pool=( "$HOME_DIR"/.wallpapers/light/* ) ;;
  *)     pool=( "$HOME_DIR"/.wallpapers/*.jpg "$HOME_DIR"/.wallpapers/*.png
               "$HOME_DIR"/.wallpapers/*.jpeg
               "$HOME_DIR"/.wallpapers/light/* "$HOME_DIR"/.wallpapers/dark/* ) ;;
esac

files=()
for f in "${pool[@]}"; do
  if [[ -f "$f" ]]; then
    files+=( "$f" )
  fi
done

if (( ${#files[@]} == 0 )); then
  echo "random-wallpaper: no wallpapers found in $HOME_DIR/.wallpapers" >&2
  exit 0
fi

WALLPAPER="$(printf '%s\n' "${files[@]}" | shuf -n 1)"

ln -sfn "$WALLPAPER" "$WALL_LINK"

awww img "$WALLPAPER" --transition-fps 60 --transition-type grow || true

MT_MODE="$(wallpaper_mode "$WALLPAPER" "$STATE")"
matugen image "$WALLPAPER" -m "$MT_MODE" --config "$MATUGEN_CONFIG"
printf '%s' "$WALLPAPER|$MT_MODE" > "$STAMP"

niri msg action load-config-file || true
quickshell ipc call theme reload || true
