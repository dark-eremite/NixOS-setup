wallpaper_mode() {
  local wall="$1" state="$2" mode
  mode="$(cat "$state" 2>/dev/null || echo auto)"
  case "$mode" in
    dark|light) printf '%s' "$mode"; return ;;
  esac
  case "$wall" in
    */light/*) printf '%s' "light" ;;
    */dark/*)  printf '%s' "dark" ;;
    *)         printf '%s' "smart" ;;
  esac
}
