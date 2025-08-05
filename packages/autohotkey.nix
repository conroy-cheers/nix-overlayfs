# Author: Libor Štěpánek 2025
{
  self,
  pkgs,
}:
self.outputs.lib.mkWinpkgsPackage {
  inherit pkgs;
  packageName = "AutoHotkey/AutoHotkey";
  version = "1.1.32.00";
  executableName = "autohotkey";
  executablePath = "/drive_c/Program Files/AutoHotkey/AutoHotkey.exe";
}
