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
    };
in
{
  packages = {
    wine-win32 = packagesWith {
      wine = winePackages.stableFull;
      wineArch = "win32";
    };
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
