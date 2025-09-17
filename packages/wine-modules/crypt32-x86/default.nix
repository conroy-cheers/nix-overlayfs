{
  lib,
  fetchurl,
  wine,
  nix-overlayfs,
  cabextract,
}:
let
  installPath = "windows/system32";
in
nix-overlayfs.lib.mkWinePackage {
  inherit wine;
  pname = "crypt32-x86";
  version = "6.1";
  src = fetchurl {
    url = "http://download.windowsupdate.com/msdownload/update/software/svpk/2011/02/windows6.1-kb976932-x86_c3516bc5c9e69fee6d9ac4f981f5b95977a8a2fa.exe";
    hash = "sha256-5USYOZVaIvxN1ZYpGv8UM7mY+Xl+HHhCMiJquh+KvZc=";
  };
  unshareInstall =
    { wineExe }:
    ''
      WIN7SP1DIR=$(pwd)/win7sp1
      mkdir -p $WIN7SP1DIR

      ${lib.getExe cabextract} -q -d $WIN7SP1DIR -L -F x86_microsoft-windows-crypt32-dll_31bf3856ad364e35_6.1.7601.17514_none_5d772bc73c15dfe5/crypt32.dll $src
      cp "$WIN7SP1DIR/x86_microsoft-windows-crypt32-dll_31bf3856ad364e35_6.1.7601.17514_none_5d772bc73c15dfe5/crypt32.dll" "$WINEPREFIX/drive_c/${installPath}"

      rm -rf $WIN7SP1DIR

      wineserver --wait
    '';
  extraPathsToInclude = [
    "${installPath}/crypt32.dll"
  ];
  packageName = "crypt32-x86";
}
