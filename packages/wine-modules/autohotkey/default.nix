# Author: Libor Štěpánek 2025
{
  wine,
  overlayfsLib,
}:
overlayfsLib.mkWinpkgsPackage {
  inherit wine;
  packageName = "AutoHotkey/AutoHotkey";
  version = "1.1.36.01";
  executableName = "autohotkey";
  executablePath = "${wine.programFiles32Path}/AutoHotkey/AutoHotkey.exe";
}
