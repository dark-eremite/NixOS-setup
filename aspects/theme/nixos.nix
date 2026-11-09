# Den aspect `theme` (NixOS part).
#
# Owns everything dynamic: darkman as the single source of truth for the mode,
# awww (swww) as the wallpaper daemon, matugen for palette generation, and the
# update-theme / random-wallpaper scripts. Nothing here needs a nixos-rebuild
# to change colors, wallpaper or theme: only IPC reloads.
#
# NOTE: this MUST be an attrset with a `nixos` module. A top-level function
# would be interpreted by den as a parametric aspect and never contribute
# `nixos` to the host. `pkgs`/`inputs` are available INSIDE the NixOS module.
{
  nixos = {
    pkgs,
    inputs,
    ...
  }:
    let
      home = "/home/dark_eremite";
      stateFile = "${home}/.local/state/darkman/theme-mode";

      # Quickshell wrapper (static shell.qml baked into the store).
      qs = import ../quickshell/wrapper.nix { inherit inputs pkgs; };

      # matugen config + templates, all in the store as REAL files in ONE
      # directory. matugen canonicalizes the config path and resolves relative
      # input_path values against that directory's parent, so a linkFarm of
      # per-file symlinks (which canonicalize to different store paths) would
      # break template resolution. Copying from the canonical aspect files
      # keeps a single source of truth in the repo.
      matugenDir = pkgs.runCommand "matugen-config" { } ''
        mkdir -p $out
        cp ${./templates/matugen.toml} $out/matugen.toml
        cp ${../niri/colors.kdl.j2} $out/colors.kdl.j2
        cp ${../quickshell/colors.qml.j2} $out/colors.qml.j2
      '';
      matugenConfig = "${matugenDir}/matugen.toml";

      # Build a script from a template, substituting @MATUGEN_CONFIG@ with the
      # store path of matugen.toml. `extraInputs` lets the scripts reference
      # each other on PATH (e.g. darkman-mode -> random-wallpaper).
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
          text = builtins.replaceStrings [ "@MATUGEN_CONFIG@" ] [ matugenConfig ] (
            builtins.readFile src
          );
          # The scripts use bash arrays; skip shellcheck's build-time lint to
          # avoid pulling a GHC toolchain into the closure.
          checkPhase = "";
        };

      updateTheme = mkScript "update-theme" ./scripts/update-theme.sh [ ];
      randomWallpaper = mkScript "random-wallpaper" ./scripts/random-wallpaper.sh [ ];
      # darkman runs this from a minimal systemd --user environment, so make
      # random-wallpaper/update-theme explicitly available on its PATH.
      darkmanMode = mkScript "darkman-mode" ./scripts/darkman-mode.sh [
        randomWallpaper
        updateTheme
      ];

      # darkman looks for mode-change scripts under $XDG_DATA_DIRS/darkman/.
      darkmanScripts = pkgs.runCommand "darkman-mode-scripts" { } ''
        mkdir -p $out/share/darkman
        ln -s ${darkmanMode}/bin/darkman-mode $out/share/darkman/theme-mode
      '';
    in
    {
      # ---- Packages --------------------------------------------------------
      # NOTE: do NOT add raw `niri`/`quickshell` here. `programs.niri.package`
      # and `qs.wrappedQuickshell` are the wrapped variants; adding the plain
      # packages would win the environment.systemPackages collision and put
      # the unwrapped binaries on PATH.
      environment.systemPackages = with pkgs; [
        awww
        matugen
        darkman
        qs.wrappedQuickshell
        updateTheme
        randomWallpaper
        darkmanMode
        darkmanScripts
      ];

      # Make darkman's script directory visible to the user systemd manager.
      environment.sessionVariables.XDG_DATA_DIRS = [ "${darkmanScripts}/share" ];

      # ---- darkman user service -------------------------------------------
      # nixpkgs has no `services.darkman` module for darkman 2.3.1, so define
      # the Type=dbus user unit manually (same as upstream darkman.service).
      systemd.user.services.darkman = {
        description = "Framework for dark-mode and light-mode transitions";
        documentation = [ "man:darkman(1)" ];
        serviceConfig = {
          Type = "dbus";
          BusName = "nl.whynothugo.darkman";
          # darkman also ships darkman.service via systemd.packages, so this
          # definition is a drop-in. For non-oneshot units a drop-in's
          # ExecStart= is additive: the empty first element emits a bare
          # `ExecStart=` that clears the packaged value before ours is set.
          ExecStart = [
            ""
            "${pkgs.darkman}/bin/darkman run"
          ];
          Restart = "on-failure";
          TimeoutStopSec = 15;
          Slice = "background.slice";
          # darkman scans $XDG_DATA_DIRS/darkman for mode-change scripts.
          Environment = "XDG_DATA_DIRS=${darkmanScripts}/share";
        };
        wantedBy = [ "default.target" ];
      };

      # darkman's D-Bus activation + portal files must be on the session bus.
      services.dbus.packages = [ pkgs.darkman ];
      xdg.portal.extraPortals = [ pkgs.darkman ];

      # ---- Initial state ---------------------------------------------------
      # Seed the single source of truth for the theme mode on first boot. The
      # file is user-owned state; only create it if missing so darkman stays
      # authoritative afterwards.
      system.activationScripts.seedThemeMode = ''
        mkdir -p ${home}/.local/state/darkman ${home}/.config/niri ${home}/.config/quickshell ${home}/.wallpapers/light ${home}/.wallpapers/dark
        if [ ! -f ${stateFile} ]; then
          printf '%s' 'auto' > ${stateFile}
          chown dark_eremite:users ${stateFile} 2>/dev/null || true
        fi
      '';

      # ---- xdg portal defaults --------------------------------------------
      xdg.portal.config.niri = {
        "org.freedesktop.impl.portal.Settings" = "darkman";
      };
    };
}
