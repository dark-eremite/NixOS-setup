{
  inputs,
  pkgs,
}:
let
  shellQml = ./shell.qml;

  wm = inputs.wrapper-manager.lib {
    inherit pkgs;
    modules = [
      {
        wrappers.quickshell = {
          basePackage = pkgs.quickshell;

          programs.quickshell.prependFlags = [
            "--path"
            "${shellQml}"
          ];
          programs.qs.prependFlags = [
            "--path"
            "${shellQml}"
          ];
        };
      }
    ];
  };
in
{
  inherit shellQml;
  wrappedQuickshell = wm.config.wrappers.quickshell.wrapped;
}
