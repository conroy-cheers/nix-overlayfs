# Author: Libor Štěpánek 2025
{
  pkgs,
  nix-overlayfs,
}:
nix-overlayfs.lib.mkWinpkgsPackage {
  inherit pkgs;
  packageName = "AutoHotkey/AutoHotkey";
  version = "1.1.36.01";
  executableName = "autohotkey";
  executablePath = "/drive_c/Program Files/AutoHotkey/AutoHotkey.exe";
}
