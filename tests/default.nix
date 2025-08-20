# Author: Libor Štěpánek 2025
# auto-import folder content
{
  pkgs,
  overlayfsLib,
}:
with pkgs;
let
  packageFiles = with builtins; removeAttrs (readDir ./.) [ "default.nix" ];
  mapFunction = name: value: {
    "${lib.strings.removeSuffix ".nix" name}" = callPackage (builtins.toPath ./. + "/${name}") {
      inherit overlayfsLib;
    };
  };
in
lib.concatMapAttrs mapFunction packageFiles
