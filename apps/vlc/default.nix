# Maintainer: Conroy Cheers <conroy@corncheese.org>
# Based on original work by Libor Štěpánek 2025
{
  fetchurl,
  runCommand,
  unzip,
  overlayfsLib,
  modules,
}:
let
  pname = "vlc-portable-x64";
  version = "3.0.21";
  src = fetchurl {
    url = "https://download.videolan.org/videolan/vlc/${version}/win64/vlc-${version}-win64.zip";
    hash = "sha256-oLfsArUK32QX7tAU+431CvOWkFBaQiW4Wz3C7RfRSEM=";
  };

  installPath = "drive_c/Program Files/VideoLAN/VLC";

  basePackage = runCommand "${pname}-${version}" {
    inherit pname version;
    nativeBuildInputs = [ unzip ];
  } ''
    mkdir -p "$out/${installPath}" extracted
    unzip -qq "${src}" -d extracted
    cp -R extracted/vlc-${version}/. "$out/${installPath}/"
  '';
in
overlayfsLib.composeWindowsLayers {
  inherit (modules) runtime;
  packageName = "VideoLAN/VLC";
  baseLayer = {
    inherit basePackage;
    overlayDependencies = [ ];
    runtimeEnvVars = { };
  };
  executableName = "vlc";
  executablePath = "${modules.runtime.programFilesPath}/VideoLAN/VLC/vlc.exe";
  workingDirectory = installPath;
}
