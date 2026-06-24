# Maintainer: Conroy Cheers <conroy@corncheese.org>
# Based on original work by Libor Stepanek 2025
{
  lib,
  pkgs,
  mkOverlayfsPackage,
  overlayfsLib,
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
  extraPostLaunchCommands ? "",
  runtimeEnvVars ? { },
  urlSchemes ? [ ],
  urlSchemeDiscoveryCommands ? "",
  urlSchemeOpenCommands ? "",
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
  hostBrowserBootstrapCommands = ''
    nix_overlayfs_configure_host_browser || true
  '';
  protocolRegistrationCommands = ''
    if [ -s "$nix_overlayfs_url_schemes_file" ]; then
      nix_overlayfs_protocol_executable=${lib.escapeShellArg executablePath}
      case "$nix_overlayfs_protocol_executable" in
        /drive_c/*)
          nix_overlayfs_protocol_executable="C:\\''${nix_overlayfs_protocol_executable#/drive_c/}"
          nix_overlayfs_protocol_executable="''${nix_overlayfs_protocol_executable//\//\\}"
          ;;
        drive_c/*)
          nix_overlayfs_protocol_executable="C:\\''${nix_overlayfs_protocol_executable#drive_c/}"
          nix_overlayfs_protocol_executable="''${nix_overlayfs_protocol_executable//\//\\}"
          ;;
        *)
          nix_overlayfs_protocol_executable="$(${runtime.toolsPackage}/bin/winepath -w "$tempdir/overlay/${executablePath}")"
          ;;
      esac
      while IFS= read -r nix_overlayfs_url_scheme; do
        nix_overlayfs_upsert_user_reg_section 'Software\\Classes\\'"$nix_overlayfs_url_scheme" <<EOF
@=$(nix_overlayfs_registry_string "URL:$nix_overlayfs_url_scheme Protocol")
"URL Protocol"=""
EOF
        nix_overlayfs_upsert_user_reg_section 'Software\\Classes\\'"$nix_overlayfs_url_scheme"'\\shell\\open\\command' <<EOF
@=$(nix_overlayfs_registry_string "\"$nix_overlayfs_protocol_executable\" \"%1\"")
EOF
      done < "$nix_overlayfs_url_schemes_file"
    fi
  '';
in
mkOverlayfsPackage {
  inherit (baseLayer) basePackage;
  inherit
    executableName
    executablePath
    workingDirectory
    entrypointWrapper
    session
    urlSchemes
    urlSchemeDiscoveryCommands
    urlSchemeOpenCommands
    ;
  extraPreLaunchCommands = hostBrowserBootstrapCommands + extraPreLaunchCommands;
  inherit extraPostLaunchCommands;
  urlSchemeRegistryCommands = protocolRegistrationCommands;
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
