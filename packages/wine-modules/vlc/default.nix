# Author: Libor Štěpánek 2025
# example with a single dependency
{
  wine,
  overlayfsLib,
  dotnet-framework-4-8,
}:
overlayfsLib.mkWinpkgsPackage {
  inherit wine;
  packageName = "VideoLAN/VLC";
  executableName = "vlc";
  executablePath = "${wine.programFiles32Path}/VideoLAN/VLC/vlc.exe";
  overlayDependencies = [ dotnet-framework-4-8 ];
}
