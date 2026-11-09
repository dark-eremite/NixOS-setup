# Builds the wrapped niri package. The static config.kdl is baked into
# /nix/store via NIRI_CONFIG; the dynamic palette is included from
# ~/.config/niri/colors.kdl at runtime (see config.kdl).
#
# Called with { inputs, pkgs } from aspects/niri/nixos.nix.
{
  inputs,
  pkgs,
}:
let
  niriConfig = ./config.kdl;

  wm = inputs.wrapper-manager.lib {
    inherit pkgs;
    modules = [
      {
        wrappers.niri = {
          basePackage = pkgs.niri;

          # Wrap ONLY the compositor binary with NIRI_CONFIG. niri-session is a
          # shell launcher that execs `niri`; it must not receive extra flags.
          programs.niri.env.NIRI_CONFIG = {
            value = "${niriConfig}";
            force = true;
          };
          programs.niri-session = { };
        };
      }
    ];
  };
in
{
  inherit niriConfig;
  wrappedNiri = wm.config.wrappers.niri.wrapped;
}
