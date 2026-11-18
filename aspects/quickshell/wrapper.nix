{
  inputs,
  pkgs,
}:
let
  shellDir = pkgs.runCommand "quickshell-config" { } ''
    mkdir -p $out
    cp ${./shell.qml} $out/shell.qml
    cp ${./BluetoothPanel.qml} $out/BluetoothPanel.qml
    cp ${./BtSection.qml} $out/BtSection.qml
    cp ${./WifiPanel.qml} $out/WifiPanel.qml
    cp ${./WifiSection.qml} $out/WifiSection.qml
    cp ${./AudioPanel.qml} $out/AudioPanel.qml
    cp ${./VolumeSlider.qml} $out/VolumeSlider.qml
    cp ${./OutputSection.qml} $out/OutputSection.qml
    cp ${./StreamSection.qml} $out/StreamSection.qml
    cp ${./MicrophonePanel.qml} $out/MicrophonePanel.qml
    cp ${./MusicPanel.qml} $out/MusicPanel.qml
    cp ${./PowerPanel.qml} $out/PowerPanel.qml
    cp ${./NotificationPopup.qml} $out/NotificationPopup.qml
    cp ${./NotificationHistoryPanel.qml} $out/NotificationHistoryPanel.qml
  '';

  notificationHistory = pkgs.writers.writePython3Bin "notification-history" {
    libraries = [ pkgs.python3Packages.dbus-fast ];
    flakeIgnore = [ "E265" "E501" "W503" ];
  } (builtins.readFile ./scripts/notification-history.py);

  wm = inputs.wrapper-manager.lib {
    inherit pkgs;
    modules = [
      {
        wrappers.quickshell = {
          basePackage = pkgs.quickshell;

          programs.quickshell.prependFlags = [
            "--path"
            "${shellDir}"
          ];
          programs.qs.prependFlags = [
            "--path"
            "${shellDir}"
          ];
        };

        wrappers.notification-history = {
          basePackage = notificationHistory;
        };
      }
    ];
  };
in
{
  inherit shellDir;
  # Both the shell and the history daemon live in one wrapper-manager bundle.
  wrappedQuickshell = wm.config.build.toplevel;
  wrappedQuickshellOnly = wm.config.wrappers.quickshell.wrapped;
  wrappedNotificationHistory = wm.config.wrappers.notification-history.wrapped;
}
