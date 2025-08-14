# Author: Libor Štěpánek 2025
# example with a single dependency
{
  pkgs,
  nix-overlayfs,
  dotnet-framework-4-8,
}:
nix-overlayfs.lib.mkWinpkgsPackage {
  inherit pkgs;
  packageName = "VideoLAN/VLC";
  executableName = "vlc";
  executablePath = "/drive_c/Program Files/VideoLAN/VLC/vlc.exe";
  overlayDependencies = [ dotnet-framework-4-8 ];
}
