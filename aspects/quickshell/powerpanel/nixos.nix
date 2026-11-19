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
      # Notification history daemon used by the power panel and notification popup.
      systemd.user.services.notification-history = {
        description = "Records desktop notifications for the Quickshell history panel";
        serviceConfig = {
          Type = "simple";
          ExecStart = "${qs.wrappedQuickshell}/bin/notification-history";
          Restart = "always";
          RestartSec = 2;
          Slice = "background.slice";
        };
        wantedBy = [ "default.target" ];
      };
    };
}
