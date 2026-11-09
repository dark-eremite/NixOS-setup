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
