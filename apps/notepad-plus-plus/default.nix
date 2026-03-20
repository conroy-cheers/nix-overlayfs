# Maintainer: Conroy Cheers <conroy@corncheese.org>
# Based on original work by Libor Štěpánek 2025
{
  fetchurl,
  runCommand,
  unzip,
  overlayfsLib,
  modules,
  binaryArch ? "x64",
}:
let
  pname = "notepad-plus-plus-portable-${binaryArch}";
  version = "8.8.5";
  release =
    {
      x64 = {
        url = "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v${version}/npp.${version}.portable.x64.zip";
        hash = "sha256-NyvTqbFVZq93k9+GISpcITc5vVfhsJqwB6HgDOTeVVs=";
      };
      arm64 = {
        url = "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v${version}/npp.${version}.portable.arm64.zip";
        hash = "sha256-DQj0KKwzI19vi2lLnJlnAj8iKiJULipcn/wqWV8/mko=";
      };
    }
    .${binaryArch};

  src = fetchurl {
    inherit (release) url hash;
  };

  installPath = "drive_c/Program Files/Notepad++";

  basePackage = runCommand "${pname}-${version}" {
    inherit pname version;
    nativeBuildInputs = [ unzip ];
  } ''
    mkdir -p "$out/${installPath}"
    unzip -qq "${src}" -d "$out/${installPath}"
  '';
in
overlayfsLib.composeWindowsLayers {
  inherit (modules) runtime;
  packageName = "Notepad++/Notepad++";
  baseLayer = {
    inherit basePackage;
    overlayDependencies = [ ];
    runtimeEnvVars = { };
  };
  executableName = "notepad++";
  executablePath = "${modules.runtime.programFilesPath}/Notepad++/notepad++.exe";
  workingDirectory = installPath;
}
