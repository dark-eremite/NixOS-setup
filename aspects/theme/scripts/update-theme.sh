#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

HOME_DIR="/home/dark_eremite"
STATE="$HOME_DIR/.local/state/darkman/theme-mode"
WALL_LINK="$HOME_DIR/.wallpapers/current"
NIRI_COLORS="$HOME_DIR/.config/niri/colors.kdl"
QS_COLORS="$HOME_DIR/.config/quickshell/colors.qml"
ALACRITTY_COLORS="$HOME_DIR/.config/alacritty/alacritty.toml"
STAMP="$HOME_DIR/.local/state/darkman/theme-source"
MATUGEN_CONFIG="@MATUGEN_CONFIG@"

@WALLPAPER_MODE@

mkdir -p "$HOME_DIR/.config/niri" "$HOME_DIR/.config/quickshell" "$HOME_DIR/.config/alacritty" "$HOME_DIR/.local/state/darkman"

WALL=""

SHOWN="$(awww query 2>/dev/null | sed -nE 's/.*currently displaying: image: (.*)$/\1/p' | head -1 || true)"
if [[ -n "$SHOWN" && -f "$SHOWN" ]]; then
  WALL="$SHOWN"
fi

if [[ -z "$WALL" && -f "$WALL_LINK" ]]; then
  WALL="$(readlink -f "$WALL_LINK")"
fi

if [[ -z "$WALL" || ! -f "$WALL" ]]; then
  for f in "$HOME_DIR"/.wallpapers/*.{jpg,png,jpeg} \
           "$HOME_DIR"/.wallpapers/dark/* \
           "$HOME_DIR"/.wallpapers/light/*; do
    if [[ -f "$f" ]]; then
      WALL="$f"
      break
    fi
  done
fi

if [[ -z "$WALL" || ! -f "$WALL" ]]; then
  niri msg action load-config-file || true
  quickshell ipc call theme reload || true
  exit 0
fi

ln -sfn "$WALL" "$WALL_LINK"

MT_MODE="$(wallpaper_mode "$WALL" "$STATE")"
SIGNATURE="$WALL|$MT_MODE"
PREVIOUS="$(cat "$STAMP" 2>/dev/null || true)"
MISSING=0
[[ -f "$NIRI_COLORS" ]] || MISSING=1
[[ -f "$QS_COLORS" ]] || MISSING=1
[[ -f "$ALACRITTY_COLORS" ]] || MISSING=1

if [[ "$PREVIOUS" != "$SIGNATURE" || "$MISSING" == "1" ]]; then
  matugen image "$WALL" -m "$MT_MODE" --config "$MATUGEN_CONFIG"
  printf '%s' "$SIGNATURE" > "$STAMP"
fi

niri msg action load-config-file || true
quickshell ipc call theme reload || true
