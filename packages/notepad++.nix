# Author: Libor Štěpánek 2025
{
  self,
  pkgs,
}:
self.outputs.lib.mkWinpkgsPackage {
  inherit pkgs;
  packageName = "Notepad++/Notepad++";
  executableName = "notepad++";
  executablePath = "/drive_c/Program Files/Notepad++/notepad++.exe";
}
