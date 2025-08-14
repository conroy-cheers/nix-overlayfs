# Author: Libor Štěpánek 2025
{
  pkgs,
  nix-gaming,
  nix-overlayfs,
}:
let
  newScope = extra: pkgs.lib.callPackageWith (pkgs // defaults // extra);
  defaults = {
    inherit (nix-gaming) wine-tkg wine-mono;
    inherit (nix-overlayfs) wine-base-env autohotkey;
    inherit nix-overlayfs;
  };
in
pkgs.lib.makeScope newScope (self: with self; {
  scripts = callPackage ./scripts { };
  mkOverlayfsPackage = callPackage ./mkOverlayfsPackage.nix { };
  mkWinePackage = callPackage ./mkWinePackage.nix { };
  mkWinpkgsPackage = callPackage ./mkWinpkgsPackage.nix { };
  diffs = {
    system = ./diffs/system.json.diff;
    user = ./diffs/user.json.diff;
    dupes = builtins.readFile ./diffs/windows_duplicates;
  };
})
