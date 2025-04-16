# Author: Libor Štěpánek 2025
{
  self,
  pkgs,
}:
self.outputs.lib.mkWinpkgsPackage {
  inherit pkgs;
  packageName = "FlorianHeidenreich/Mp3tag";
  executableName = "mp3tag";
  executablePath = "/drive_c/Program Files/Mp3tag/Mp3tag.exe";
}
