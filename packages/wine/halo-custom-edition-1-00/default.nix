{
  fetchurl,
  nix-overlayfs,
  msvcp60,
  msxml4,
  wine,
  mingw,
}:
let
  chktrustSrc = ./chktrust.cpp;
  gpp = "/drive_c/Program\ Files/CodeBlocks/MinGW/bin/g++.exe";
  patchSrc = fetchurl {
    url = "https://web.archive.org/web/20141022155617/http://halo.bungie.net/images/games/halopc/patch/110/haloce-patch-1.0.10.exe";
    hash = "sha256-M4GPP1a33dyMYdZUr2VnycW5IgynXWrCOlJhEDgldQg=";
  };
in
nix-overlayfs.lib.mkWinePackage {
  inherit wine;
  pname = "halo-custom-edition";
  version = "1.00";
  src = fetchurl {
    url = "http://vaporeon.io/hosted/halo/original_files/halocesetup_en_1.00.exe";
    hash = "sha256-ARsDthY0Vh18G2CQ5yKf4KLfQN4sKhS0WsjwRV1dmQ8=";
  };
  ahkScript = builtins.readFile ./install.ahk;
  postInstall =
    ''
      DESTDIR="$WINEPREFIX/drive_c/Program Files (x86)/Microsoft Games/Halo Custom Edition"
      # DESTPATH="$DESTDIR/haloce-patch-1.0.10.exe"
      # cp "${patchSrc}" "$DESTPATH"

      wine "$WINEPREFIX${gpp}" "${chktrustSrc}" -o chktrust.exe
      mv chktrust.exe "$DESTDIR"

      # cd "$DESTDIR"
      # wine "$DESTPATH"
      wine "${patchSrc}"

      wineserver --wait
      # rm "$DESTPATH"
    '';
  overlayDependencies = [ msvcp60 msxml4 mingw ];
  packageName = "halo-custom-edition";
  executableName = "haloce";
  executablePath = "/drive_c/Program Files (x86)/Microsoft Games/Halo Custom Edition/haloce.exe";
  launchVncServer = true;
}
