{
  lib,
  writeText,
  caladea,
  carlito,
  dejavu_fonts,
  liberation_ttf,
  noto-fonts,
  runtime,
  overlayfsLib,
}:
let
  fontPackages = [
    caladea
    carlito
    dejavu_fonts
    liberation_ttf
    noto-fonts
  ];
in
overlayfsLib.mkWindowsPackage {
  inherit runtime;
  pname = "fonts";
  version = "2";
  src = writeText "fonts-noop.txt" "";
  packageName = "fonts";
  unshareInstall = { session, ... }: ''
    font_dir="$WINEPREFIX/drive_c/windows/Fonts"

    mkdir -p "$font_dir"
    ${lib.concatMapStringsSep "\n" (pkg: ''
      find ${pkg} -type f \( -iname '*.ttf' -o -iname '*.ttc' -o -iname '*.otf' \) \
        -exec cp {} "$font_dir/" \;
    '') fontPackages}

    ${session.commands.wineboot} -u
    ${session.commands.wineserver} --wait
  '';
  passthru = {
    inherit fontPackages;
  };
}
