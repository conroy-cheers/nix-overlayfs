{
  lib,
  fetchzip,

  overlayfsLib,
  wine,
  halo-custom-edition,

  dxvk,
}:
let
  installPath = "windows/system32";
  dllsToInstall = [
    "d3d8.dll"
    "d3d9.dll"
    "d3d10core.dll"
    "d3d11.dll"
    "dxgi.dll"
  ];
in
overlayfsLib.mkWinePackage {
  inherit wine;
  inherit (dxvk) pname version;
  src = lib.getBin dxvk;
  unshareInstall =
    { wineExe }:
    ''
      cp $src/x32/* "$WINEPREFIX/drive_c/${installPath}"
    '';
  extraPathsToInclude = map (x: installPath + "/" + x) dllsToInstall;
  packageName = "dxvk";
  runtimeEnvVars = {
    WINEDLLOVERRIDES = "d3d8,d3d9,d3d10core,d3d11,dxgi=n";
  };
}
