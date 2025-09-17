{
  pkgs,
  nix-gaming,
  nix-overlayfs,
}:
{
  winePackages = pkgs.callPackage ./wine-packages.nix { inherit nix-gaming nix-overlayfs; };
}
