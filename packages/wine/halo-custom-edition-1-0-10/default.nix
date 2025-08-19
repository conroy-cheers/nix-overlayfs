{
  pkgs,
  nix-overlayfs,
  msvcp60,
  msxml4,
  halo-custom-edition-1-00,
}:
nix-overlayfs.lib.mkWinePackage rec {
  pname = "halo-custom-edition";
  version = "1.0.10";
  src = pkgs.fetchurl {
    url = "https://web.archive.org/web/20141022155617/http://halo.bungie.net/images/games/halopc/patch/110/haloce-patch-1.0.10.exe";
    hash = "sha256-M4GPP1a33dyMYdZUr2VnycW5IgynXWrCOlJhEDgldQg=";
  };
  unshareInstall =
    { wineExe }:
    ''
      DESTDIR="$WINEPREFIX/drive_c/Program Files (x86)/Microsoft Games/Halo Custom Edition"
      DESTPATH="$DESTDIR/haloce-patch-1.0.10.exe"

      sleep 10

      cp $src "$DESTPATH"

      ls -lrth "$DESTDIR"

      cd "$DESTDIR"
      ${wineExe} "$DESTPATH"

      wineserver --wait
    '';
  # ahkScript = builtins.readFile ./install.ahk;
  overlayDependencies = [
    msvcp60
    msxml4
    halo-custom-edition-1-00
  ];
  packageName = "halo-custom-edition";
  executableName = "haloce";
  executablePath = "/drive_c/Program Files (x86)/Microsoft Games/Halo Custom Edition/haloce.exe";
  winePkg = pkgs.wineWow64Packages.stagingFull;
  launchVncServer = true;
}
