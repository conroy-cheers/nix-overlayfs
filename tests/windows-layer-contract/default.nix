{
  pkgs,
  overlayfsLib,
}:
let
  emptyRegistry = pkgs.writeText "empty-wine-registry.json" "{}";

  baseEnvironment = pkgs.runCommand "windows-layer-contract-base-environment" { } ''
    mkdir -p "$out/basePackage/drive_c"
    for registry in system user userdef; do
      cp ${emptyRegistry} "$out/basePackage/$registry.json"
    done
    printf '1\n' > "$out/basePackage/.update-timestamp"
  '';

  hiddenDependency = pkgs.runCommand "windows-layer-contract-hidden-dependency" { } ''
    mkdir -p "$out/basePackage"
    printf dependency > "$out/basePackage/.dependency-hidden"
  '';

  fakeTools = pkgs.runCommand "windows-layer-contract-tools" { } ''
    mkdir -p "$out/bin"
    for tool in wine wineserver wineboot winecfg; do
      ln -s ${pkgs.coreutils}/bin/true "$out/bin/$tool"
    done
  '';

  fakeRuntime = rec {
    windowsArch = "wow64";
    programFilesPath = "/drive_c/Program Files";
    programFiles32Path = "/drive_c/Program Files (x86)";
    toolsPackage = fakeTools;
    baseEnvLayer = baseEnvironment;
    autohotkeyLayer = null;
    selectBaseEnvLayer = _: baseEnvironment;
    mkSession =
      {
        overlayRoot,
        homeDir,
        ...
      }:
      {
        buildInputs = [ ];
        env = {
          HOME = ''"${homeDir}"'';
          WINEPREFIX = ''"${overlayRoot}"'';
          WINEARCH = "wow64";
        };
        preCommands = "";
        postCommands = "";
        commands = {
          wine = "${fakeTools}/bin/wine";
          wineserver = "${fakeTools}/bin/wineserver";
        };
      };
  };

  package = overlayfsLib.mkWindowsPackage {
    runtime = fakeRuntime;
    pname = "windows-layer-contract-package";
    version = "1.0.0";
    src = pkgs.writeText "windows-layer-contract-source" "";
    packageName = "WindowsLayerContract";
    executableName = "";
    overlayDependencies = [ hiddenDependency ];
    buildNamespaceMode = "direct";
    hostIntegration = false;
    unshareInstall = _: ''
      test "$(<"$WINEPREFIX/.dependency-hidden")" = dependency
      printf installer > "$WINEPREFIX/.installer-hidden"
      printf probe > "$WINEPREFIX/drive_c/layer-probe"
    '';
  };

  nativeBaseEnvironment =
    if pkgs.stdenv.hostPlatform.isx86_64 then
      pkgs.nix-overlayfs.moduleScopes.nativeModules."base-env"
    else
      null;
in
pkgs.runCommand "windows-layer-contract-test" { } ''
  test "$(<"${package.basePackage}/.installer-hidden")" = installer
  ${pkgs.lib.optionalString (nativeBaseEnvironment != null) ''
    test -s "${nativeBaseEnvironment}/basePackage/.update-timestamp"
    ${pkgs.coreutils}/bin/tr -d '\r\n' \
      < "${nativeBaseEnvironment}/basePackage/.update-timestamp" \
      | ${pkgs.gnugrep}/bin/grep -Eq '^[0-9]+$'
  ''}
  touch "$out"
''
