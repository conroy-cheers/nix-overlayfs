{
  pkgs,
  nix-gaming,
  nix-gaming-legacy,
  overlayfsLib,
}:
let
  mkWinePackages = pkgs.callPackage ./wine-packages.nix {
    inherit overlayfsLib;
  };
in
{
  wine-win32 = mkWinePackages {
    wineBasePkg = pkgs.winePackages.stableFull;
    wineArch = "win32";
  };
  wine-ge-win32 = mkWinePackages {
    wineBasePkg = nix-gaming-legacy.wine-ge;
    wineArch = "win32";
  };
  wine-tkg-wow64 = mkWinePackages {
    wineBasePkg = nix-gaming.wine-tkg;
    wineArch = "wow64";
  };
}
