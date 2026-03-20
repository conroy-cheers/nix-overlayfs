# Maintainer: Conroy Cheers <conroy@corncheese.org>
# Based on original work by Libor Štěpánek 2025
{
  lib,
  runCommand,
  fetchurl,
  mkWindowsPackage,

  yj,

  overlayfsLib,
}:
{
  runtime,
  packageName,
  executableName ? "",
  executablePath ? "",
  version ? "latest",
  overlayDependencies ? [ ],
  extraPathsToRemove ? [ ],
  silentFlags ? null,
  launchVncServer ? false,
  runtimeEnvVars ? { },
  ...
}:
let
  scripts = overlayfsLib.scripts;

  # Get path from package name, select the correct manifest file, convert it to JSON and import it as an attribute set
  manifest =
    let
      manifest-json = (
        runCommand "winpkgsPath" { nativeBuildInputs = [ yj ]; } ''
          ${scripts.getWinpkgsPath} '${packageName}' '${version}' > $out
        ''
      );
    in
    builtins.fromJSON (builtins.readFile "${manifest-json}");

  preferredArchitectures =
    if runtime ? preferredInstallerArchitectures then
      runtime.preferredInstallerArchitectures
    else if runtime ? preferredInstallerArchitecture then
      [ runtime.preferredInstallerArchitecture ]
    else if runtime.windowsArch == "win32" then
      [ "x86" ]
    else
      [ "x64" ];

  matchingInstallersFor = arch: builtins.filter (x: x.Architecture == arch) manifest.Installers;

  candidateInstallers = builtins.concatLists (builtins.map matchingInstallersFor preferredArchitectures);

  # Select the installer files based on the preferred Windows binary architecture for the runtime.
  installer = builtins.head (
    builtins.filter (x: (x.InstallerType or "exe") != "zip") (
      candidateInstallers ++ (matchingInstallersFor "neutral")
    )
  );

  # Group installer types for silent flag selection
  installerType = installer.InstallerType or manifest.InstallerType or "exe";

  # Predefined set of silent flags
  silentFlagsIndex = {
    nullsoft = "/S";
    inno = "/VERYSILENT";
    exe = manifest.InstallerSwitches.Silent;
  };
  # Use supplied silent flags or default to predefined ones
  silentFlag = if silentFlags != null then silentFlags else silentFlagsIndex.${installerType};
in
mkWindowsPackage {
  inherit runtime;

  # Extract metadata from manifest
  pname = manifest.PackageIdentifier;
  version = manifest.PackageVersion;

  # Download selected installer
  src = fetchurl {
    url = installer.InstallerUrl;
    sha256 = "${installer.InstallerSha256}";
  };

  silentFlags = silentFlag;

  inherit
    packageName
    executableName
    executablePath
    overlayDependencies
    extraPathsToRemove
    launchVncServer
    runtimeEnvVars
    ;
}
