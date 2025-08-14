# Author: Libor Štěpánek 2025
# auto-import folder content
{
  pkgs,
  nix-overlayfs,
}:
with pkgs;
let
  packageFiles = with builtins; removeAttrs (readDir ./.) [ "default.nix" ];
  mapFunction = name: value: {
    "${lib.strings.removeSuffix ".nix" name}" = callPackage (builtins.toPath ./. + "/${name}") {
      inherit nix-overlayfs;
    };
  };
in
lib.concatMapAttrs mapFunction packageFiles
