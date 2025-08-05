# Author: Libor Štěpánek 2025
{
  pkgs,
  self,
  ...
}:
rec {
  scripts = pkgs.callPackage ./scripts { };
  mkOverlayfsPackage = pkgs.callPackage ./mkOverlayfsPackage.nix { };
  mkWinePackage = pkgs.callPackage ./mkWinePackage.nix { inherit diffs mkOverlayfsPackage self; };
  mkWinpkgsPackage = pkgs.callPackage ./mkWinpkgsPackage.nix {
    inherit diffs mkWinePackage self;
  };
  diffs = {
    system = ./diffs/system.json.diff;
    user = ./diffs/user.json.diff;
    dupes = builtins.readFile ./diffs/windows_duplicates;
  };
}
