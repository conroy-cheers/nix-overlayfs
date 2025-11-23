{
  pkgs,
  wineWow64Modules,
  overlayfsLib,
}:
let
  mkApp = name: pkg: {
    type = "app";
    program = "${pkg}/bin/${pkg.meta.executableName}";
  };

  appDefinitions = {
    notepad-plus-plus = pkgs.callPackage ./notepad-plus-plus {
      inherit wineWow64Modules overlayfsLib;
    };
    vlc = pkgs.callPackage ./vlc {
      inherit wineWow64Modules overlayfsLib;
    };
  };
in
{
  apps = builtins.mapAttrs mkApp appDefinitions;
}
