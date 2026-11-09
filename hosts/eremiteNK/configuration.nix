# Host-specific configuration for eremiteNK.
# User accounts, hostname and the desktop stack are owned by den aspects in
# /aspects; this file keeps the machine-level bits (boot, network, packages).

{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

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

  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    alacritty
    opencode
    git
  ];

  # This value is fixed for the lifetime of the installation. See the NixOS
  # manual before ever changing it.
  system.stateVersion = "26.05";
}
