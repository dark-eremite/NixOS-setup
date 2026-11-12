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
  '';

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
      }
    ];
  };
in
{
  inherit shellDir;
  wrappedQuickshell = wm.config.wrappers.quickshell.wrapped;
}
