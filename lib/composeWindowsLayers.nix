# Maintainer: Conroy Cheers <conroy@corncheese.org>
# Based on original work by Libor Stepanek 2025
{
  lib,
  pkgs,
  mkOverlayfsPackage,
}:
{
  runtime,
  packageName,
  baseLayer,
  overlayDependencies ? [ ],
  executableName,
  executablePath,
  workingDirectory ? null,
  extraPreLaunchCommands ? "",
  runtimeEnvVars ? { },
  entrypointWrapper ? (entrypoint: ''exec ${entrypoint} "$@"''),
  ...
}:

let
  winedbg = "-all";
  baseEnv = [ runtime.baseEnvLayer ];
  allLayers = [ baseLayer ] ++ overlayDependencies;
  allRuntimeEnvVars = lib.mergeAttrsList (
    (builtins.map (layer: layer.runtimeEnvVars) allLayers) ++ [ runtimeEnvVars ]
  );
  session = runtime.mkSession {
    phase = "launch";
    sessionRoot = "$tempdir/runtime-session";
    overlayRoot = "$tempdir/overlay";
    homeDir = "$HOME";
  };
in
mkOverlayfsPackage {
  inherit (baseLayer) basePackage;
  inherit
    executableName
    executablePath
    workingDirectory
    extraPreLaunchCommands
    entrypointWrapper
    session
    ;
  overlayDependencies = baseEnv ++ baseLayer.overlayDependencies ++ overlayDependencies;
  launchProgram = session.commands.wine;
  basePackageName = packageName;
  extraEnvCommands = ''
    export WINEDEBUG="''${WINEDEBUG:-${winedbg}}"
  ''
  + builtins.concatStringsSep "\n" (
    lib.mapAttrsToList (n: v: "export ${n}='${v}'") allRuntimeEnvVars
  );
}
