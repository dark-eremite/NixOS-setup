{
  inputs,
  pkgs,
}:
let
  discordVencord = pkgs.discord.override { withVencord = true; };

  wm = inputs.wrapper-manager.lib {
    inherit pkgs;
    modules = [
      {
        wrappers.discord = {
          basePackage = discordVencord;
          env.NIXOS_OZONE_WL = "1";
          programs.Discord = { };
        };
      }
    ];
  };
in
{
  inherit discordVencord;
  wrappedDiscord = wm.config.wrappers.discord.wrapped;
}

