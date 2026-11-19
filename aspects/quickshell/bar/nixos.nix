{
  nixos = {
    pkgs,
    inputs,
    ...
  }:
    let
      qs = import ../wrapper.nix { inherit inputs pkgs; };
    in
    {
      # Bar shell (bluetooth, wifi, audio, microphone, music panels + bar UI).
      environment.systemPackages = [ qs.wrappedQuickshell ];
    };
}
