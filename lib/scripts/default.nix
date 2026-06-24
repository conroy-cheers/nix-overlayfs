# Maintainer: Conroy Cheers <conroy@corncheese.org>
# Based on original work by Libor Štěpánek 2025
{ pkgs }:
{
  reg2json = pkgs.callPackage ./reg2json.nix { };
  json2reg = pkgs.callPackage ./json2reg.nix { };
  mergeWineRegistries = pkgs.callPackage ./merge-wine-registries.nix { };
  getWinpkgsPath = pkgs.callPackage ./getWinpkgsPath.nix { };
}
