# Author: Libor Štěpánek 2025
# example with a single dependency
{
  self,
  pkgs,
}:
self.outputs.lib.mkWinpkgsPackage {
  inherit pkgs;
  packageName = "VideoLAN/VLC";
  executableName = "vlc";
  executablePath = "/drive_c/Program Files/VideoLAN/VLC/vlc.exe";
  overlayDependencies = with self.packages.x86_64-linux; [dotnet-framework-4-8];
}
