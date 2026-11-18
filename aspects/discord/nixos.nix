{
  nixos = {
    inputs,
    pkgs,
    ...
  }:
    let
      wrapped = import ./wrapper.nix { inherit inputs pkgs; };
    in
    {
      environment.systemPackages = [ wrapped.wrappedDiscord ];
    };
}
