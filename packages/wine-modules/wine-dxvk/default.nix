{
  lib,

  overlayfsLib,
  runtime,

  dxvk,
}:
let
  installPath32 =
    if runtime.windowsArch == "wow64" then
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
overlayfsLib.mkWindowsPackage {
  inherit runtime;
  inherit (dxvk) pname version;
  src = lib.getBin dxvk;
  unshareInstall =
    { ... }:
    ''
      cp $src/x32/* "$WINEPREFIX/drive_c/${installPath32}"
    ''
    + lib.optionalString (runtime.windowsArch == "wow64") ''
      cp $src/x64/* "$WINEPREFIX/drive_c/${installPath64}"
    '';
  extraPathsToInclude =
    (map (x: installPath32 + "/" + x) dllsToInstall)
    ++ lib.optionals (runtime.windowsArch == "wow64") (map (x: installPath64 + "/" + x) dllsToInstall);
  packageName = "dxvk";
  runtimeEnvVars = {
    WINEDLLOVERRIDES = "d3d8,d3d9,d3d10core,d3d11,dxgi=n";
  };
}
