{
  lib,
  fetchurl,
  wine,
  nix-overlayfs,
  cabextract,
}:
let
  cabPath = "amd64_microsoft-windows-crypt32-dll_31bf3856ad364e35_6.1.7601.17514_none_b995c74af473511b/crypt32.dll";
  installPath = "windows/syswow64";
in
nix-overlayfs.lib.mkWinePackage {
  inherit wine;
  pname = "crypt32-x64";
  version = "6.1";
  src = fetchurl {
    url = "http://download.windowsupdate.com/msdownload/update/software/svpk/2011/02/windows6.1-kb976932-x64_74865ef2562006e51d7f9333b4a8d45b7a749dab.exe";
    hash = "sha256-9NHUGNkbFhloikgmgO4DL/0rZeQgxtLq7PiqN2KqZMg=";
  };
  unshareInstall =
    { wineExe }:
    ''
      WIN7SP1DIR=$(pwd)/win7sp1
      mkdir -p $WIN7SP1DIR

      ${lib.getExe cabextract} -q -d $WIN7SP1DIR -L -F ${cabPath} $src
      cp "$WIN7SP1DIR/${cabPath}" "$WINEPREFIX/drive_c/${installPath}"

      rm -rf $WIN7SP1DIR

      wineserver --wait
    '';
  extraPathsToInclude = [
    "${installPath}/crypt32.dll"
  ];
  packageName = "crypt32-x64";
}
