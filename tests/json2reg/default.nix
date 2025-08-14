# Author: Libor Štěpánek 2025
# test cases for the json2reg script
{
  pkgs,
  nix-overlayfs,
  ...
}:
pkgs.stdenv.mkDerivation {
  pname = "reg2json_test";
  version = "1.0.0";
  nativeBuildInputs =
    with pkgs;
    with nix-overlayfs.lib.scripts;
    [
      findutils
      diffutils
      json2reg
    ];
  src = ./.;
  buildPhase = ''
    for file in *.json; do
      filenoext=''${file%.json}
      json2reg "$file" "$filenoext.reg.new"
      diff $filenoext.reg $filenoext.reg.new
    done
  '';

  installPhase = "touch $out";
}
