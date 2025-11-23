# Maintainer: Conroy Cheers <conroy@corncheese.org>
# Based on original work by Libor Štěpánek 2025
{
  overlayfsLib,
  wineWow64Modules,
}:
overlayfsLib.mkWinpkgsPackage {
  inherit (wineWow64Modules) wine;
  packageName = "VideoLAN/VLC";
  executableName = "vlc";
  executablePath = "${wineWow64Modules.wine.programFiles32Path}/VideoLAN/VLC/vlc.exe";
  overlayDependencies = with wineWow64Modules; [ dotnet-framework-4-8 ];
}
