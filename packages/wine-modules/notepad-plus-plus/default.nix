# Author: Libor Štěpánek 2025
{
  wine,
  overlayfsLib,
}:
overlayfsLib.mkWinpkgsPackage {
  inherit wine;
  packageName = "Notepad++/Notepad++";
  executableName = "notepad++";
  executablePath = "${wine.programFilesPath}/Notepad++/notepad++.exe";
}
