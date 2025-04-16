# Author: Libor Štěpánek 2025
# an example with multiple dependencies and extra paths for removal during the build process
{
  self,
  pkgs,
}:
self.outputs.lib.mkWinpkgsPackage {
  inherit pkgs;
  packageName = "Nikse/SubtitleEdit";
  executableName = "subtitleedit";
  executablePath = "/drive_c/Program Files/Subtitle Edit/SubtitleEdit.exe";
  overlayDependencies = with self.packages.x86_64-linux; [dotnet-framework-4-8 vlc];
  extraPathsToRemove = ["Program Files/Subtitle Edit/unins000.dat"];
}
