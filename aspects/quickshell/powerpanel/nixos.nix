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
      environment.systemPackages = with pkgs; [
        cliphist
        wl-clipboard
        grim
        iproute2
      ];

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

      systemd.user.services.cliphist = {
        description = "Clipboard history watcher for cliphist";
        after = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.writeShellScript "cliphist-watch" ''
            ${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store &
            exec ${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store
          ''}";
          Restart = "always";
          RestartSec = 2;
          Slice = "background.slice";
        };
        wantedBy = [ "graphical-session.target" ];
      };
    };
}
