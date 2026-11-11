# Общая логика разрешения режима палитры для random-wallpaper и update-theme.
# Вставляется в оба скрипта на этапе сборки (см. nixos.nix) — один источник
# истины, без дублирования.
#
# Приоритет:
#   1. darkman явно выставлен в dark/light → его значение приоритетнее, даже
#      если обои лежат в «противоположной» папке.
#   2. иначе (auto / неизвестное значение) → решает папка обоев:
#        .../light/... → light, .../dark/... → dark.
#   3. нейтральные обои в корне ~/.wallpapers → smart (matugen сам по яркости).
#
# STATE-файл darkman (theme-mode) намеренно НЕ изменяется: вычисленный режим
# передаётся только в matugen через -m.
#
# $1 — путь к файлу обоев, $2 — путь к state-файлу darkman.
# Вывод: dark | light | smart
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
