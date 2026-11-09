# Den aspect `niri` (NixOS part).
#
# `nixos` here is a normal NixOS module. The `inputs` module argument is made
# available by `den.batteries.flake-scope` (wired in flake.nix), which lets us
# call wrapper-manager.lib and build the wrapped package with the host's pkgs.
#
# `programs.niri.package` is set to the wrapper so the display-manager session,
# xdg portals and `niri msg` all resolve to the same binary carrying
# NIRI_CONFIG -> the store-owned static config.kdl.
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
      programs.niri = {
        enable = true;
        package = wrapped.wrappedNiri;
      };

      # Upstream niri.service has an absolute ExecStart pointing at the
      # unwrapped store binary; point it at our wrapper instead.
      #
      # niri.service comes from `systemd.packages` (the niri package), so our
      # definition lands as a drop-in (overrides.conf). For non-oneshot
      # services a drop-in's ExecStart= is ADDITIVE, not replacing: the first
      # empty string emits a bare `ExecStart=` which clears the base unit's
      # value, then the second line sets ours. Without it systemd refuses the
      # unit with "more than one ExecStart= setting".
      systemd.user.services.niri = {
        serviceConfig.ExecStart = lib.mkForce [
          ""
          "${wrapped.wrappedNiri}/bin/niri --session"
        ];
        restartIfChanged = false;
        enableDefaultPath = false;
      };

      environment.systemPackages = [
        # swww was renamed to awww in nixpkgs. Keep `swww`/`swww-daemon` as
        # compatibility aliases for anything still using the old names.
        (pkgs.runCommand "swww-compat" { } ''
          mkdir -p $out/bin
          ln -s ${pkgs.awww}/bin/awww $out/bin/swww
          ln -s ${pkgs.awww}/bin/awww-daemon $out/bin/swww-daemon
        '')
      ];

      # The quickshell bar's digits use this nerd font.
      fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];
    };
}
