# Author: Libor Štěpánek 2025
{
  lib,
  runCommand,
  fetchurl,
  mkWinePackage,
  diffs,

  yj,

  overlayfsLib,
}:
{
  wine,
  packageName,
  executableName ? "",
  executablePath ? "",
  version ? "latest",
  overlayDependencies ? [ ],
  extraPathsToRemove ? [ ],
  silentFlags ? null,
  launchVncServer ? false,
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

  # Select the installer files based on the architecture
  installer = builtins.head (
    builtins.filter (x: (x.InstallerType or "exe") != "zip") (
      (lib.optionals (wine.wineArch != "win32") (
        builtins.filter (x: x.Architecture == "x64") manifest.Installers
      ))
      ++ (lib.optionals (wine.wineArch == "win32") (
        builtins.filter (x: x.Architecture == "x86") manifest.Installers
      ))
      ++ (builtins.filter (x: x.Architecture == "neutral") manifest.Installers)
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
mkWinePackage {
  inherit wine;

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
    ;
}
