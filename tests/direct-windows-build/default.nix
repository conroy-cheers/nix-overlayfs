{
  pkgs,
  overlayfsLib,
}:
overlayfsLib.mkWindowsPackage {
  runtime = pkgs.nix-overlayfs.moduleScopes.nativeModules.runtime;
  pname = "direct-windows-build";
  version = "1";
  src = pkgs.writeText "direct-windows-build-noop.txt" "";
  packageName = "direct-windows-build";
  buildNamespaceMode = "direct";
  unshareInstall = { session, ... }: ''
    ${session.commands.winecfg} -v win10
    ${session.commands.wineserver} --wait
  '';
}
