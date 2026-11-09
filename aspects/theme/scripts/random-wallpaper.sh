#!/usr/bin/env bash
# Pick a random wallpaper for the current theme mode, apply it through the
# awww (swww) daemon, regenerate the palette and reload niri + quickshell.
#
# Bound to Mod+W in aspects/niri/config.kdl. Also used by darkman's
# mode-change script so switching dark/light reshuffles the wallpaper.
set -o errexit
set -o nounset
set -o pipefail

HOME_DIR="/home/dark_eremite"
STATE="$HOME_DIR/.local/state/darkman/theme-mode"
WALL_LINK="$HOME_DIR/.wallpapers/current"
MATUGEN_CONFIG="@MATUGEN_CONFIG@"

mkdir -p "$HOME_DIR/.wallpapers/light" "$HOME_DIR/.wallpapers/dark"

MODE="$(cat "$STATE" 2>/dev/null || echo auto)"
case "$MODE" in
  dark)  pool=( "$HOME_DIR"/.wallpapers/dark/* ) ;;
  light) pool=( "$HOME_DIR"/.wallpapers/light/* ) ;;
  *)     pool=( "$HOME_DIR"/.wallpapers/*.jpg "$HOME_DIR"/.wallpapers/*.png
               "$HOME_DIR"/.wallpapers/*.jpeg
               "$HOME_DIR"/.wallpapers/light/* "$HOME_DIR"/.wallpapers/dark/* ) ;;
esac

# Keep only regular files, drop directories and unexpanded globs.
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

# `shuf` comes from coreutils (added to the script's runtime PATH by Nix).
WALLPAPER="$(printf '%s\n' "${files[@]}" | shuf -n 1)"

ln -sfn "$WALLPAPER" "$WALL_LINK"

# swww was renamed to awww in nixpkgs; `awww img` is the same IPC client.
# Non-fatal: at session start the daemon may not be up yet. The wallpaper
# symlink and palette below are still generated so update-theme can catch up.
awww img "$WALLPAPER" --transition-fps 60 --transition-type grow || true

if [[ "$MODE" == "auto" ]]; then
  MT_MODE="smart"
else
  MT_MODE="$MODE"
fi
matugen image "$WALLPAPER" -m "$MT_MODE" --config "$MATUGEN_CONFIG"

# Reload matrix: niri IPC + quickshell IPC. Non-fatal: these are signals to
# already-running clients; missing clients simply means "no live reload yet"
# (the config file watcher / QML file watcher will pick the change up).
niri msg action load-config-file || true
quickshell ipc call theme reload || true
