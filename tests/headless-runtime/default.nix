{
  pkgs,
  overlayfsLib,
}:
let
  modules = pkgs.nix-overlayfs.moduleScopes.nativeWin32HeadlessModules;

  basePackage = pkgs.stdenvNoCC.mkDerivation {
    pname = "headless-runtime-base";
    version = "1.0.0";
    dontUnpack = true;
    installPhase = ''
      mkdir -p "$out/bin"
      touch "$out/bin/headless-runtime.exe"
    '';
  };

  package = overlayfsLib.composeWindowsLayers {
    inherit (modules) runtime;
    packageName = "headless-runtime-test";
    baseLayer = {
      inherit basePackage;
      overlayDependencies = [ ];
      runtimeEnvVars = { };
    };
    executableName = "headless-runtime";
    executablePath = "bin/headless-runtime.exe";
    hostIntegration = false;
    managedRuntime = "disabled";
    namespaceMode = "direct";
    stateMode = "ephemeral";
  };

  closure = pkgs.closureInfo { rootPaths = [ package ]; };
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "headless-runtime-test";
  version = "1.0.0";
  dontUnpack = true;

  buildPhase = ''
    entry="${package}/bin/headless-runtime-unwrapped"
    setup="${package}/libexec/headless-runtime-setupEnv.sh"

    grep -F 'export appdir="$tempdir/upper"' "$entry"
    grep -F 'export XDG_DATA_HOME="$tempdir/xdg-data"' "$entry"
    grep -F 'export XDG_CACHE_HOME="$tempdir/xdg-cache"' "$entry"
    grep -F 'export WINEDLLOVERRIDES="mscoree,mshtml=d' "$entry"
    grep -F "trap 'exit 143' TERM" "$entry" "$setup"
    grep -F 'fusermount3 -uz' "$entry" "$setup"

    ! grep -Fx '${overlayfsLib.hostUrlOpener}' ${closure}/store-paths
    ! grep -Fx '${overlayfsLib.hostStartShim}' ${closure}/store-paths
    ! grep -Fx '${pkgs.xdg-utils}' ${closure}/store-paths
    ! grep -Fx '${pkgs.desktop-file-utils}' ${closure}/store-paths

    test '${if package.hostIntegration then "true" else "false"}' = false
    test '${package.stateMode}' = ephemeral
    test '${(builtins.head package.overlayDependencies).managedRuntime}' = disabled
    test '${
      if (builtins.head package.overlayDependencies).hostIntegration then "true" else "false"
    }' = false
  '';

  installPhase = "touch $out";
}
