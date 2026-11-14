{
  nixos = {
    config,
    lib,
    pkgs,
    ...
  }:
    let
      normalUserList = lib.attrValues (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);
      lockUser =
        if builtins.length normalUserList == 1 then
          builtins.head normalUserList
        else
          throw "lockscreen: set services.greetd.settings.initial_session.user for multiple normal users";

      hyprlockConf = pkgs.writeText "hyprlock.conf" (builtins.readFile ./hyprlock.conf);

      fallbackWallpaper = pkgs.runCommand "hyprlock-fallback-wallpaper" { } ''
        mkdir -p $out
        printf 'P6\n1 1\n255\n\36\36\36' > $out/fallback.ppm
      '';

      bootSession = pkgs.writeShellScriptBin "boot-session" ''
        export PATH="$PATH:${lib.makeBinPath (with pkgs; [
          coreutils
          awww
          niri
          hyprlock
          procps
          gnused
          systemd
          bash
        ])}"
        ${builtins.replaceStrings
          [ "@FALLBACK@" "@LOCK_CONFIG@" ]
          [ "${fallbackWallpaper}/fallback.ppm" "${hyprlockConf}" ]
          (builtins.replaceStrings [ "#!/usr/bin/env bash" ] [ "" ] (builtins.readFile ./scripts/boot-session.sh))}
      '';
    in
    {
      environment.systemPackages = with pkgs; [ hyprlock bootSession ];

      security.pam.services.hyprlock.allowNullPassword = false;

      systemd.user.services.hypridle.enable = false;

      system.activationScripts.seedLockColors = {
        deps = [ "users" ];
        text = lib.concatMapStringsSep "\n" (u: ''
          install -d -o ${u.name} -g users -m 0755 "${u.home}/.config/hyprlock"
          if [ ! -f "${u.home}/.config/hyprlock/colors.conf" ]; then
            cp ${./colors-fallback.conf} "${u.home}/.config/hyprlock/colors.conf"
            chown ${u.name}:users "${u.home}/.config/hyprlock/colors.conf"
          fi
        '') normalUserList;
      };

      services.greetd = {
        enable = true;
        restart = false;
        settings = {
          terminal.vt = 1;
          initial_session = {
            user = lockUser.name;
            command = "${bootSession}/bin/boot-session";
          };
          default_session = {
            user = "greeter";
            command = "${pkgs.greetd}/bin/agreety --cmd ${bootSession}/bin/boot-session";
          };
        };
      };
    };
}
