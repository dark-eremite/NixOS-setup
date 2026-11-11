# Системные пакеты без wrapper-manager: ставятся как есть из nixpkgs.
# Обёрнутые приложения живут в aspects/*/wrapper.nix и подключаются
# соответствующими аспектами, сюда они не попадают.
{ pkgs }:

with pkgs; [
  vim
  wget
  curl
  opencode
  git
  vscode
]
