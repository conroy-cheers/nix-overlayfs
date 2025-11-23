# Maintainer: Conroy Cheers <conroy@corncheese.org>
# Based on original work by Libor Štěpánek 2025
{
  lib,
  pkgs,
  mkOverlayfsPackage,
}:
{
  wine,
  packageName,
  baseLayer,
  overlayDependencies ? [ ],
  executableName,
  executablePath,
  workingDirectory ? null,
  extraPreLaunchCommands ? "",
  runtimeEnvVars ? { },
  ...
}:

let
  winedbg = "-all";
  baseEnv = [ wine.wine-base-env ];
  allLayers = [ baseLayer ] ++ overlayDependencies;
  allRuntimeEnvVars = lib.mergeAttrsList (
    (builtins.map (layer: layer.runtimeEnvVars) allLayers) ++ [ runtimeEnvVars ]
  );
in
mkOverlayfsPackage {
  inherit (baseLayer) basePackage;
  inherit
    executableName
    executablePath
    workingDirectory
    extraPreLaunchCommands
    ;
  overlayDependencies = baseEnv ++ baseLayer.overlayDependencies ++ overlayDependencies;
  interpreter = lib.getExe wine;
  basePackageName = packageName;
  extraEnvCommands = ''
    export WINEPREFIX="$tempdir/overlay"
    export WINEDEBUG="${winedbg}"
  ''
  + builtins.concatStringsSep "\n" (
    lib.mapAttrsToList (n: v: "export ${n}='${v}'") allRuntimeEnvVars
  );
}
