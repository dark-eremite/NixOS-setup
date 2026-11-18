{
  nixos = {
    config,
    lib,
    pkgs,
    inputs,
    ...
  }:
    let
      normalUsers = lib.filterAttrs (_: u: u.isNormalUser) config.users.users;

      qs = import ../quickshell/wrapper.nix { inherit inputs pkgs; };

      matugenDir = pkgs.runCommand "matugen-config" { } ''
        mkdir -p $out
        cp ${./templates/matugen.toml} $out/matugen.toml
        cp ${../niri/colors.kdl.j2} $out/colors.kdl.j2
        cp ${../quickshell/colors.qml.j2} $out/colors.qml.j2
        cp ${./alacritty.toml} $out/alacritty.toml.j2
        cp ${../lockscreen/colors.conf.j2} $out/hyprlock.conf.j2
      '';
      matugenConfig = "${matugenDir}/matugen.toml";

      alacrittyFallbackConfig = pkgs.writeText "alacritty.toml" (builtins.readFile ./alacritty-fallback.toml);
      alacritty = pkgs.writeShellScriptBin "alacritty" ''
        config="$HOME/.config/alacritty/alacritty.toml"
        if [ ! -f "$config" ]; then
          config=${alacrittyFallbackConfig}
        fi
        exec ${pkgs.alacritty}/bin/alacritty --config-file "$config" "$@"
      '';

      mkScript =
        name: src: extraInputs:
        pkgs.writeShellApplication {
          inherit name;
          runtimeInputs = with pkgs; [
            coreutils
            matugen
            niri
            awww
            qs.wrappedQuickshell
            bash
          ] ++ extraInputs;
          text = builtins.replaceStrings
            [ "@MATUGEN_CONFIG@" "@WALLPAPER_MODE@" ]
            [ matugenConfig (builtins.readFile ./scripts/wallpaper-mode.sh) ]
            (builtins.readFile src);
          checkPhase = "";
        };

      updateTheme = mkScript "update-theme" ./scripts/update-theme.sh [ ];
      randomWallpaper = mkScript "random-wallpaper" ./scripts/random-wallpaper.sh [ ];
      darkmanMode = mkScript "darkman-mode" ./scripts/darkman-mode.sh [
        randomWallpaper
        updateTheme
      ];

      darkmanScripts = pkgs.runCommand "darkman-mode-scripts" { } ''
        mkdir -p $out/share/darkman
        ln -s ${darkmanMode}/bin/darkman-mode $out/share/darkman/theme-mode
      '';
    in
    {
      environment.systemPackages = with pkgs; [
        awww
        matugen
        darkman
        qs.wrappedQuickshell
        alacritty
        updateTheme
        randomWallpaper
        darkmanMode
        darkmanScripts
      ];

      environment.sessionVariables.XDG_DATA_DIRS = [ "${darkmanScripts}/share" ];

      systemd.user.services.darkman = {
        description = "Framework for dark-mode and light-mode transitions";
        documentation = [ "man:darkman(1)" ];
        serviceConfig = {
          Type = "dbus";
          BusName = "nl.whynothugo.darkman";
          ExecStart = [
            ""
            "${pkgs.darkman}/bin/darkman run"
          ];
          Restart = "on-failure";
          TimeoutStopSec = 15;
          Slice = "background.slice";
          Environment = "XDG_DATA_DIRS=${darkmanScripts}/share";
        };
        wantedBy = [ "default.target" ];
      };

      services.dbus.packages = [ pkgs.darkman ];
      xdg.portal.extraPortals = [ pkgs.darkman ];

      system.activationScripts.seedThemeMode = {
        deps = [ "users" ];
        text = lib.concatMapStringsSep "\n" (
          u:
          let
            stateFile = "${u.home}/.local/state/darkman/theme-mode";
          in
          ''
            install -d -o ${u.name} -g users -m 0755 \
              "${u.home}/.local/state/darkman" \
              "${u.home}/.config/niri" \
              "${u.home}/.config/quickshell" \
              "${u.home}/.config/hyprlock" \
              "${u.home}/.wallpapers/light" \
              "${u.home}/.wallpapers/dark"
            if [ ! -f "${stateFile}" ]; then
              printf '%s' 'auto' > "${stateFile}"
              chown ${u.name}:users "${stateFile}"
            fi
          ''
        ) (lib.attrValues normalUsers);
      };

      xdg.portal.config.niri = {
        "org.freedesktop.impl.portal.Settings" = "darkman";
      };
    };
}
