# Maintainer: Conroy Cheers <conroy@corncheese.org>
# Based on original work by Libor Štěpánek 2025
{
  runtime,
  overlayfsLib,
}:
overlayfsLib.mkWinpkgsPackage {
  inherit runtime;
  packageName = "AutoHotkey/AutoHotkey";
  version = "1.1.36.01";
  executableName = "autohotkey";
  executablePath = "${runtime.programFilesPath}/AutoHotkey/AutoHotkey.exe";
}
