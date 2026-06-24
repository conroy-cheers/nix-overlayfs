{
  writeText,
  runtime,
  overlayfsLib,
}:
overlayfsLib.mkWindowsPackage {
  inherit runtime;
  pname = "win10";
  version = "1";
  src = writeText "win10-noop.txt" "";
  packageName = "win10";
  unshareInstall = { session, ... }: ''
    ${session.commands.winecfg} -v win10
    ${session.commands.wineserver} --wait
  '';
}
