# Author: Libor Štěpánek 2025
{pkgs}: {
  reg2json = pkgs.callPackage ./reg2json.nix {};
  json2reg = pkgs.callPackage ./json2reg.nix {};
  getWinpkgsPath = pkgs.callPackage ./getWinpkgsPath.nix {};
}
