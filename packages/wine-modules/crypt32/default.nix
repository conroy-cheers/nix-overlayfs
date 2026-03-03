{
  lib,
  fetchurl,
  wine,
  overlayfsLib,
  cabextract,
}:
let
  x86CabPath = "x86_microsoft-windows-crypt32-dll_31bf3856ad364e35_6.1.7601.17514_none_5d772bc73c15dfe5/crypt32.dll";
  x64CabPath = "amd64_microsoft-windows-crypt32-dll_31bf3856ad364e35_6.1.7601.17514_none_b995c74af473511b/crypt32.dll";

  installX86 = wine.wineArch != "win64";
  installX64 = wine.wineArch != "win32";

  installPath32 = if wine.wineArch == "win32" then "windows/system32" else "windows/syswow64";
  installPath64 = "windows/system32";

  x86Src = fetchurl {
    url = "http://download.windowsupdate.com/msdownload/update/software/svpk/2011/02/windows6.1-kb976932-x86_c3516bc5c9e69fee6d9ac4f981f5b95977a8a2fa.exe";
    hash = "sha256-5USYOZVaIvxN1ZYpGv8UM7mY+Xl+HHhCMiJquh+KvZc=";
  };

  x64Src = fetchurl {
    url = "http://download.windowsupdate.com/msdownload/update/software/svpk/2011/02/windows6.1-kb976932-x64_74865ef2562006e51d7f9333b4a8d45b7a749dab.exe";
    hash = "sha256-9NHUGNkbFhloikgmgO4DL/0rZeQgxtLq7PiqN2KqZMg=";
  };
in
overlayfsLib.mkWinePackage {
  inherit wine;
  pname = "crypt32";
  version = "6.1";
  src = if installX64 then x64Src else x86Src;
  unshareInstall =
    { wineExe }:
    ''
      WIN7SP1DIR=$(pwd)/win7sp1
      mkdir -p "$WIN7SP1DIR"

      ${lib.optionalString installX86 ''
        ${lib.getExe cabextract} -q -d "$WIN7SP1DIR" -L -F ${x86CabPath} '${x86Src}'
        cp "$WIN7SP1DIR/${x86CabPath}" "$WINEPREFIX/drive_c/${installPath32}"
      ''}

      ${lib.optionalString installX64 ''
        ${lib.getExe cabextract} -q -d "$WIN7SP1DIR" -L -F ${x64CabPath} '${x64Src}'
        cp "$WIN7SP1DIR/${x64CabPath}" "$WINEPREFIX/drive_c/${installPath64}"
      ''}

      rm -rf "$WIN7SP1DIR"

      wineserver --wait
    '';
  extraPathsToInclude =
    lib.optionals installX86 [ "${installPath32}/crypt32.dll" ]
    ++ lib.optionals installX64 [ "${installPath64}/crypt32.dll" ];
  packageName = "crypt32";
}
