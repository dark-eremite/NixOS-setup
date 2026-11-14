{
  nixos = {
    lib,
    pkgs,
    inputs,
    ...
  }:
    let
      wrapped = import ./wrapper.nix { inherit inputs pkgs; };
    in
    {
      # niri 26.04 has no config option to stop an interactive window move from
      # creating a workspace when dropped in the gap between two workspaces.
      # Patch insert_position() so drops snap to the nearest named (template)
      # workspace instead. An overlay keeps every pkgs.niri consumer (the
      # wrapped compositor, the systemd unit and the `niri msg` CLI in the
      # theme scripts) on the same binary.
      nixpkgs.overlays = [
        (final: prev: {
          niri = prev.niri.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [
              ./patches/no-new-workspaces.patch
            ];
          });
        })
      ];

      programs.niri = {
        enable = true;
        package = wrapped.wrappedNiri;
      };

      systemd.user.services.niri = {
        serviceConfig.ExecStart = lib.mkForce [
          ""
          "${wrapped.wrappedNiri}/bin/niri --session"
        ];
        restartIfChanged = false;
        enableDefaultPath = false;
      };

      environment.systemPackages = [
        (pkgs.runCommand "swww-compat" { } ''
          mkdir -p $out/bin
          ln -s ${pkgs.awww}/bin/awww $out/bin/swww
          ln -s ${pkgs.awww}/bin/awww-daemon $out/bin/swww-daemon
        '')
      ];

      fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];
    };
}
