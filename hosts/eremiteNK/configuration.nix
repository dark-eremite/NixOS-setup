{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./users.nix
  ];

  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
    useOSProber = true;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Moscow";

  fileSystems."/".options = [ "compress=zstd" ];

  programs.firefox.enable = true;

  environment.systemPackages = import ../../packages.nix { inherit pkgs; };

  # This value is fixed for the lifetime of the installation. See the NixOS
  # manual before ever changing it.
  system.stateVersion = "26.05";
}
