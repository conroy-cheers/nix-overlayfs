{
  lib,

  overlayfsLib,
  wine,

  dxvk,
}:
let
  installPath32 =
    if wine.wineArch == "wow64" then
      "windows/syswow64"
    else
      "windows/system32";
  installPath64 = "windows/system32";
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
      cp $src/x32/* "$WINEPREFIX/drive_c/${installPath32}"
    ''
    + lib.optionalString (wine.wineArch == "wow64") ''
      cp $src/x64/* "$WINEPREFIX/drive_c/${installPath64}"
    '';
  extraPathsToInclude =
    (map (x: installPath32 + "/" + x) dllsToInstall)
    ++ lib.optionals (wine.wineArch == "wow64") (map (x: installPath64 + "/" + x) dllsToInstall);
  packageName = "dxvk";
  runtimeEnvVars = {
    WINEDLLOVERRIDES = "d3d8,d3d9,d3d10core,d3d11,dxgi=n";
  };
}
