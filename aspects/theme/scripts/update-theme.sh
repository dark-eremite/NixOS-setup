#!/usr/bin/env bash
# Regenerate the dynamic color files from the current wallpaper if they are
# missing, then reload niri + quickshell through IPC only.
#
# This script NEVER needs a nixos-rebuild. Everything dynamic lives in
# ~/.config/ and ~/.wallpapers/. The one source of truth for the theme mode is
# ~/.local/state/darkman/theme-mode.
set -o errexit
set -o nounset
set -o pipefail

HOME_DIR="/home/dark_eremite"
STATE="$HOME_DIR/.local/state/darkman/theme-mode"
WALL_LINK="$HOME_DIR/.wallpapers/current"
NIRI_COLORS="$HOME_DIR/.config/niri/colors.kdl"
QS_COLORS="$HOME_DIR/.config/quickshell/colors.qml"
MATUGEN_CONFIG="@MATUGEN_CONFIG@"

mkdir -p "$HOME_DIR/.config/niri" "$HOME_DIR/.config/quickshell"

MODE="$(cat "$STATE" 2>/dev/null || echo auto)"
case "$MODE" in
  dark|light|auto) ;;
  *) MODE="auto" ;;
esac

# matugen 4: `auto` in AGENT.md maps to the `smart` scheme mode (matugen
# decides dark/light from image brightness). dark/light stay explicit.
if [[ "$MODE" == "auto" ]]; then
  MT_MODE="smart"
else
  MT_MODE="$MODE"
fi

# Materialize colors.* when absent (AGENT.md § "Материализация файлов").
if [[ ! -f "$NIRI_COLORS" || ! -f "$QS_COLORS" ]]; then
  WALL=""
  if [[ -f "$WALL_LINK" ]]; then
    WALL="$(readlink -f "$WALL_LINK")"
  fi
  if [[ -z "$WALL" || ! -f "$WALL" ]]; then
    # Pick the first available wallpaper as a fallback: neutral root first,
    # then the mode-specific pools.
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

# Reload matrix: niri IPC + quickshell IPC. No rebuild, no restart of the WM.
# Non-fatal: clients may not be running yet at session start; niri's config
# watcher and quickshell's QML file watcher will apply the change when they are.
niri msg action load-config-file || true
quickshell ipc call theme reload || true
