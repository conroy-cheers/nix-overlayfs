# Author: Libor Štěpánek 2025
{
  pkgs,
  overlayfsLib,
}:
let
  newScope = extra: pkgs.lib.callPackageWith (pkgs // defaults // extra);
  defaults = {
    inherit overlayfsLib;
  };
in
pkgs.lib.makeScope newScope (
  self: with self; {
    scripts = callPackage ./scripts { };
    mkOverlayfsPackage = callPackage ./mkOverlayfsPackage.nix { };
    mkWinePackage = callPackage ./mkWinePackage.nix { };
    mkWinpkgsPackage = callPackage ./mkWinpkgsPackage.nix { };
    diffs = {
      system = ./diffs/system.json.diff;
      user = ./diffs/user.json.diff;
      dupes = builtins.filter (s: s != "") (
        pkgs.lib.splitString "\n" (builtins.readFile ./diffs/windows_duplicates)
      );
    };
  }
)
