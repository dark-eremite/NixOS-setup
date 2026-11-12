#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

export PATH="/run/current-system/sw/bin:$PATH"

WALL_LINK="$HOME/.wallpapers/current"
FALLBACK="@FALLBACK@"
LOCK_CONFIG="@LOCK_CONFIG@"

mkdir -p "${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}" || true

niri-session &
niri_pid=$!

wayland_display=""
for _ in $(seq 1 150); do
  env_dump="$(systemctl --user show-environment 2>/dev/null || true)"
  candidate="$(printf '%s\n' "$env_dump" | sed -n 's/^WAYLAND_DISPLAY=//p' | head -1)"
  if [[ -n "$candidate" && -S "${XDG_RUNTIME_DIR}/${candidate}" ]]; then
    wayland_display="$candidate"
    export WAYLAND_DISPLAY="$candidate"
    niri_socket="$(printf '%s\n' "$env_dump" | sed -n 's/^NIRI_SOCKET=//p' | head -1)"
    if [[ -n "$niri_socket" ]]; then
      export NIRI_SOCKET="$niri_socket"
    fi
    break
  fi
  if ! kill -0 "$niri_pid" 2>/dev/null; then
    wait "$niri_pid" || true
    exit 1
  fi
  sleep 0.1
done

if [[ -z "$wayland_display" ]]; then
  wait "$niri_pid" || true
  exit 1
fi

awww-daemon &

wall=""
if [[ -f "$WALL_LINK" ]]; then
  wall="$(readlink -f "$WALL_LINK")"
fi
if [[ ! -f "$wall" ]]; then
  wall="$FALLBACK"
fi

for _ in $(seq 1 50); do
  if awww img "$wall" --transition-type none >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

hyprlock --config "$LOCK_CONFIG" &
lock_pid=$!

for _ in $(seq 1 50); do
  if ! kill -0 "$lock_pid" 2>/dev/null; then
    break
  fi
  if loginctl show-session "${XDG_SESSION_ID:-}" -p LockedHint --value 2>/dev/null | grep -q '^yes$'; then
    break
  fi
  sleep 0.1
done

quickshell &
update-theme &

wait "$niri_pid"
