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
MATUGEN_CONFIG="@MATUGEN_CONFIG@"

mkdir -p "$HOME_DIR/.config/niri" "$HOME_DIR/.config/quickshell" "$HOME_DIR/.config/alacritty"

MODE="$(cat "$STATE" 2>/dev/null || echo auto)"
case "$MODE" in
  dark|light|auto) ;;
  *) MODE="auto" ;;
esac

if [[ "$MODE" == "auto" ]]; then
  MT_MODE="smart"
else
  MT_MODE="$MODE"
fi

if [[ ! -f "$NIRI_COLORS" || ! -f "$QS_COLORS" || ! -f "$ALACRITTY_COLORS" ]]; then
  WALL=""
  if [[ -f "$WALL_LINK" ]]; then
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
  if [[ -n "$WALL" && -f "$WALL" ]]; then
    matugen image "$WALL" -m "$MT_MODE" --config "$MATUGEN_CONFIG"
  fi
fi

niri msg action load-config-file || true
quickshell ipc call theme reload || true
