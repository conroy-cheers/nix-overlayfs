{
  pkgs,
  nix-gaming,
  nix-overlayfs,
}:
{
  winePackages = import ./wine { inherit pkgs nix-gaming nix-overlayfs; };
}
