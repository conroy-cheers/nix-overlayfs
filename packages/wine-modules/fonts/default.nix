{
  lib,
  writeText,
  liberation_ttf,
  runtime,
  overlayfsLib,
}:
overlayfsLib.mkWindowsPackage {
  inherit runtime;
  pname = "fonts";
  version = lib.getVersion liberation_ttf;
  src = writeText "fonts-noop.txt" "";
  packageName = "fonts";
  unshareInstall = { session, ... }: ''
    font_dir="$WINEPREFIX/drive_c/windows/Fonts"

    mkdir -p "$font_dir"
    find ${liberation_ttf} -type f \( -iname '*.ttf' -o -iname '*.ttc' -o -iname '*.otf' \) \
      -exec cp {} "$font_dir/" \;

    ${session.commands.wineboot} -u
    ${session.commands.wineserver} --wait
  '';
}
