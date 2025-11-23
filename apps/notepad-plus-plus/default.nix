# Maintainer: Conroy Cheers <conroy@corncheese.org>
# Based on original work by Libor Štěpánek 2025
{
  overlayfsLib,
  wineWow64Modules,
}:
overlayfsLib.mkWinpkgsPackage {
  inherit (wineWow64Modules) wine;
  packageName = "Notepad++/Notepad++";
  executableName = "notepad++";
  executablePath = "${wineWow64Modules.wine.programFilesPath}/Notepad++/notepad++.exe";
  runtimeEnvVars = {
    DISPLAY = "wine";
  };
}
