{
  lib,
  fetchurl,
  runtime,
  overlayfsLib,
  cabextract,

  dllsToInstall ? [
    "asycfilt.dll"
    "comcat.dll"
    "mfc42.dll"
    "mfc42u.dll"
    "msvcirt.dll"
    "msvcp60.dll"
    "msvcrt.dll"
    "oleaut32.dll"
    "olepro32.dll"
    "stdole2.tlb"
  ],
}:
let
  installPath =
    if runtime.windowsArch == "wow64" then
      "windows/syswow64"
    else
      "windows/system32";
in
overlayfsLib.mkWindowsPackage {
  inherit runtime;
  pname = "msvcp";
  version = "6.0";
  src = fetchurl {
    url = "https://web.archive.org/web/20120627225622/http://download.microsoft.com/download/vc60pro/update/1/w9xnt4/en-us/vc6redistsetup_enu.exe";
    hash = "sha256-z50N2WjnjV5oWm6mq1jsQ4rArCQxaxTScbAs88ztZ9k=";
  };
  unshareInstall =
    { session, ... }:
    ''
      # Extract vcredist.exe
      mkdir vcrun6
      VCRUN6DIR=$(pwd)/vcrun6
      ${session.commands.wine} "$src" "/T:Z:$VCRUN6DIR" /c /q

      ${lib.getExe cabextract} -q -d $VCRUN6DIR $VCRUN6DIR/vcredist.exe

      for dll in ${lib.concatStringsSep " " dllsToInstall}; do
          cp "$VCRUN6DIR/$dll" "$WINEPREFIX/drive_c/${installPath}"
      done
      rm -rf $VCRUN6DIR

      ${session.commands.wineserver} --wait
    '';
  extraPathsToInclude = map (x: installPath + "/" + x) dllsToInstall;
  packageName = "msvcp60";
}
