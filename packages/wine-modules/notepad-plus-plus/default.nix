# Author: Libor Štěpánek 2025
{
  wine,
  nix-overlayfs,
}:
nix-overlayfs.lib.mkWinpkgsPackage {
  inherit wine;
  packageName = "Notepad++/Notepad++";
  executableName = "notepad++";
  executablePath = "/drive_c/Program Files/Notepad++/notepad++.exe";
}
