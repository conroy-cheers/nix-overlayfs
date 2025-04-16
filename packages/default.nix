# Author: Libor Štěpánek 2025
# automatically import all .nix files in this directory
{
  self,
  pkgs,
}:
with pkgs; let
  packageFiles = with builtins; removeAttrs (readDir ./.) ["default.nix"];
  mapFunction = name: value: {"${lib.strings.removeSuffix ".nix" name}" = callPackage (builtins.toPath ./. + "/${name}") {inherit self;};};
in
  lib.concatMapAttrs mapFunction packageFiles
