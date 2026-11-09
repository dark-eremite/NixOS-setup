{
  description = "NixOS config for eremiteNK — den aspects + wrapper-manager, niri + quickshell + matugen + darkman";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    den.url = "github:denful/den";
    # The old GitHub repo is gone; wrapper-manager lives on Codeberg now.
    wrapper-manager.url = "git+https://codeberg.org/viperML/wrapper-manager";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      { den, ... }:
      {
        imports = [ inputs.den.flakeModule ];

        systems = [ "x86_64-linux" ];

        # Expose `inputs` (and lib/den) to every aspect pipeline module, so the
        # NixOS modules can call wrapper-manager.lib with the host's pkgs.
        den.default.includes = [ den.batteries.flake-scope ];

        # ---- Host ----------------------------------------------------------
        den.hosts.x86_64-linux.eremiteNK = {
          users.dark_eremite = { };

          # nixpkgs' nixosSystem has no `inputs` special arg by default. Wrap
          # the default instantiate so NixOS aspect modules can call
          # wrapper-manager.lib (and reach the wrapper-manager flake input).
          # spec.instantiate is called as `f { modules; ... }`.
          instantiate =
            args:
            inputs.nixpkgs.lib.nixosSystem (
              args // {
                specialArgs = (args.specialArgs or { }) // {
                  inherit inputs;
                };
              }
            );
        };

        # ---- Host aspect ---------------------------------------------------
        den.aspects.eremiteNK = {
          includes = [
            den.batteries.hostname
            den.batteries.define-user
            den.batteries.primary-user
            den.aspects.niri
            den.aspects.theme
          ];

          nixos = {
            imports = [ ./hosts/eremiteNK/configuration.nix ];

            # Host-local additions that were not in the original configuration.
            users.users.dark_eremite.extraGroups = [ "wheel" "networkmanager" ];
          };
        };

        # ---- Feature aspects -----------------------------------------------
        # Each aspect file is a den aspect (an attrset with a `nixos` module).
        # The quickshell wrapper lives in aspects/quickshell/wrapper.nix and is
        # installed by the theme aspect (which owns the dynamic/reload system).
        den.aspects.niri = import ./aspects/niri/nixos.nix;
        den.aspects.theme = import ./aspects/theme/nixos.nix;
      }
    );
}
