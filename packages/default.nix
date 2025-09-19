{
  pkgs,
  nix-gaming,
  nix-overlayfs,
}:
{
  winePrograms = pkgs.callPackage ./wine-packages.nix { inherit nix-gaming nix-overlayfs; };
}
