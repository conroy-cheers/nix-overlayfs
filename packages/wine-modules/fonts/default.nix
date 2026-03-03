{
  lib,
  writeText,
  liberation_ttf,
  wine,
  overlayfsLib,
}:
overlayfsLib.mkWinePackage {
  inherit wine;
  pname = "fonts";
  version = lib.getVersion liberation_ttf;
  src = writeText "fonts-noop.txt" "";
  packageName = "fonts";
  unshareInstall = { }: ''
    font_dir="$WINEPREFIX/drive_c/windows/Fonts"

    mkdir -p "$font_dir"
    find ${liberation_ttf} -type f \( -iname '*.ttf' -o -iname '*.ttc' -o -iname '*.otf' \) \
      -exec cp {} "$font_dir/" \;

    ${lib.getExe' wine "wineboot"} -u
    wineserver --wait
  '';
}
