{
  inputs,
  pkgs,
}:
let
  shellDir = pkgs.runCommand "quickshell-config" { } ''
    mkdir -p $out
    cp ${./bar/shell.qml} $out/shell.qml
    cp ${./bar/BluetoothPanel.qml} $out/BluetoothPanel.qml
    cp ${./bar/BtSection.qml} $out/BtSection.qml
    cp ${./bar/WifiPanel.qml} $out/WifiPanel.qml
    cp ${./bar/WifiSection.qml} $out/WifiSection.qml
    cp ${./bar/AudioPanel.qml} $out/AudioPanel.qml
    cp ${./bar/VolumeSlider.qml} $out/VolumeSlider.qml
    cp ${./bar/OutputSection.qml} $out/OutputSection.qml
    cp ${./bar/StreamSection.qml} $out/StreamSection.qml
    cp ${./bar/MicrophonePanel.qml} $out/MicrophonePanel.qml
    cp ${./bar/MusicPanel.qml} $out/MusicPanel.qml
    cp ${./powerpanel/PowerPanel.qml} $out/PowerPanel.qml
    cp ${./powerpanel/TrayMenu.qml} $out/TrayMenu.qml
    cp ${./powerpanel/NotificationPopup.qml} $out/NotificationPopup.qml
    cp ${./powerpanel/NotificationHistoryPanel.qml} $out/NotificationHistoryPanel.qml
    cp ${./powerpanel/ClipboardHistoryPanel.qml} $out/ClipboardHistoryPanel.qml
    cp ${./powerpanel/ColorPickerPanel.qml} $out/ColorPickerPanel.qml
    cp ${./powerpanel/ScreenColorPicker.qml} $out/ScreenColorPicker.qml
    cp ${./powerpanel/PortsPanel.qml} $out/PortsPanel.qml
  '';

  notificationHistory = pkgs.writers.writePython3Bin "notification-history" {
    libraries = [ pkgs.python3Packages.dbus-fast ];
    flakeIgnore = [ "E265" "E501" "W503" ];
  } (builtins.readFile ./powerpanel/scripts/notification-history.py);

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
