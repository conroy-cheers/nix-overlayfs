# Author: Libor Štěpánek 2025
{
  pkgs,
  nix-overlayfs,
}:
nix-overlayfs.lib.mkWinpkgsPackage {
  inherit pkgs;
  packageName = "Notepad++/Notepad++";
  executableName = "notepad++";
  executablePath = "/drive_c/Program Files/Notepad++/notepad++.exe";
}
