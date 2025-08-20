{
  lib,
  wine,
  wineArch ? "wow64",
  runCommand,
  makeWrapper,
  symlinkJoin,
}:

let
  wineExeName =
    {
      "win32" = "wine";
      "win64" = "wine64";
      "wow64" = "wine";
    }
    .${wineArch};

  wineWrapped =
    runCommand "${wine}-${wineArch}"
      {
        nativeBuildInputs = [ makeWrapper ];

        meta.mainProgram = "wine-wrapped";
      }
      ''
        makeWrapper ${lib.getExe' wine wineExeName} $out/bin/wine-wrapped \
          --set WINEARCH "${wineArch}"
      '';
in
symlinkJoin {
  pname = "${if (wine ? "pname") then wine.pname else "wine"}-${wineArch}-wrapped";
  version = if (wine ? "version") then wine.version else (lib.getVersion wine);

  paths = [
    wine
    wineWrapped
  ];
  meta = wine.meta // {
    mainProgram = "wine-wrapped";
  };

  passthru = {
    inherit wineArch;
    programFiles32Path = "/drive_c/Program Files" + (if wineArch == "win32" then "" else " (x86)");
    programFilesPath = "/drive_c/Program Files";
  };
}
