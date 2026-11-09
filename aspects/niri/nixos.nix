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
