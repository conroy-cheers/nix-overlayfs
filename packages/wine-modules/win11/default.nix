{
  writeText,
  runtime,
  overlayfsLib,
}:
overlayfsLib.mkWindowsPackage {
  inherit runtime;
  pname = "win11";
  version = "1";
  src = writeText "win11-noop.txt" "";
  packageName = "win11";
  unshareInstall = { session, ... }: ''
    ${session.commands.winecfg} -v win11
    ${session.commands.wineserver} --wait
  '';
}
