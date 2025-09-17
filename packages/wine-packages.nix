{
  lib,
  callPackage,
  winePackages,
  nix-gaming,
  nix-overlayfs,
}:

let
  packagesWith =
    { wine, wineArch }:
    callPackage ./wine-modules {
      inherit wine wineArch nix-overlayfs;
      inherit (nix-gaming) wine-mono;
    };
in
{
  packages = {
    wine-ge-win32 = packagesWith {
      wine = nix-gaming.wine-ge;
      wineArch = "win32";
    };
    wine-tkg-wow64 = packagesWith {
      wine = nix-gaming.wine-tkg;
      wineArch = "wow64";
    };
  };
}
