# Author: Libor Štěpánek 2025
# test cases for the reg2json script
{
  pkgs,
  nix-overlayfs,
}:
pkgs.stdenv.mkDerivation {
  pname = "reg2json_test";
  version = "1.0.0";
  nativeBuildInputs =
    with pkgs;
    with nix-overlayfs.lib.scripts;
    [
      findutils
      jd-diff-patch
      reg2json
    ];
  src = ./.;
  buildPhase = ''
    for file in *.reg; do
      filenoext=''${file%.reg}
      reg2json "$file" > "$filenoext.json.new"
      jd -f=merge "$filenoext.json" "$filenoext.json.new"
    done
  '';

  installPhase = "touch $out";
}
