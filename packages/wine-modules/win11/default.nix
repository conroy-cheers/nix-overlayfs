{
  lib,
  writeText,
  wine,
  overlayfsLib,
}:
overlayfsLib.mkWinePackage {
  inherit wine;
  pname = "win11";
  version = "1";
  src = writeText "win11-noop.txt" "";
  packageName = "win11";
  unshareInstall = { }: ''
    ${lib.getExe' wine "winecfg"} -v win11
    wineserver --wait
  '';
}
