{ ... }:

{
  users.users.dark_eremite = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };
}
