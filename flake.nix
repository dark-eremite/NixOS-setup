{
  description = "dark_eremite's NixOS config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    den.url = "github:denful/den";
    wrapper-manager.url = "git+https://codeberg.org/viperML/wrapper-manager";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      { den, ... }:
      {
        imports = [ inputs.den.flakeModule ];

        systems = [ "x86_64-linux" ];

        den.default.includes = [ den.batteries.flake-scope ];

        den.hosts.x86_64-linux.eremiteNK = {
          users.dark_eremite = { };

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

            users.users.dark_eremite.extraGroups = [ "wheel" "networkmanager" ];

            hardware.bluetooth = {
              enable = true;
              powerOnBoot = true;
            };
          };
        };

        den.aspects.niri = import ./aspects/niri/nixos.nix;
        den.aspects.theme = import ./aspects/theme/nixos.nix;
      }
    );
}
