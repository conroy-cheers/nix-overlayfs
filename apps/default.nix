{
  winePackageSets,
}:
let
  mkApp = name: pkg: {
    type = "app";
    program = "${pkg}/bin/${pkg.meta.executableName}";
  };

  appDefinitions = {
    halo-custom-edition = winePackageSets.wine-ge-win32.halo-custom-edition;
    notepad-plus-plus = winePackageSets.wine-tkg-wow64.notepad-plus-plus;
  };
in
{
  apps = builtins.mapAttrs mkApp appDefinitions;
  packages = appDefinitions;
}
