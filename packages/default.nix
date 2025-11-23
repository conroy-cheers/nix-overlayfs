{
  pkgs,
  nix-gaming,
  nix-gaming-legacy,
  overlayfsLib,
}:
let
  mkWineModules = pkgs.callPackage ./mk-wine-modules.nix {
    inherit overlayfsLib;
  };
in
{
  wineWin32Modules = mkWineModules {
    wineBasePkg = pkgs.winePackages.stableFull;
    wineArch = "win32";
  };
  wineWow64Modules = mkWineModules {
    wineBasePkg = pkgs.wineWow64Packages.unstableFull;
    wineArch = "wow64";
  };
  wineGeWin32Modules = mkWineModules {
    wineBasePkg = nix-gaming-legacy.wine-ge;
    wineArch = "win32";
  };
  wineTkgWow64Modules = mkWineModules {
    wineBasePkg = nix-gaming.wine-tkg;
    wineArch = "wow64";
  };
  inherit mkWineModules;
}
