let
  bar = import ./bar/nixos.nix;
  powerpanel = import ./powerpanel/nixos.nix;
in
{
  includes = [ bar powerpanel ];
  inherit bar powerpanel;
}
