# Builds the wrapped quickshell package: the static shell.qml is baked into
# /nix/store via `QS_CONFIG_PATH` (quickshell reads the QML from that path).
# The dynamic palette is loaded at runtime from
# file:///home/dark_eremite/.config/quickshell/colors.qml (see shell.qml).
#
# Called with { inputs, pkgs } from the theme/nixos aspect or flake.nix.
{
  inputs,
  pkgs,
}:
let
  shellQml = ./shell.qml;

  wm = inputs.wrapper-manager.lib {
    inherit pkgs;
    modules = [
      {
        wrappers.quickshell = {
          basePackage = pkgs.quickshell;

          # quickshell's own flag for selecting a config by path is `--path`.
          # Use prependFlags so the static QML path is always supplied.
          programs.quickshell.prependFlags = [
            "--path"
            "${shellQml}"
          ];
          programs.qs.prependFlags = [
            "--path"
            "${shellQml}"
          ];
        };
      }
    ];
  };
in
{
  inherit shellQml;
  wrappedQuickshell = wm.config.wrappers.quickshell.wrapped;
}
