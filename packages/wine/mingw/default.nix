{
  wine,
  nix-overlayfs,
}:
nix-overlayfs.lib.mkWinpkgsPackage {
  inherit wine;
  packageName = "CodeBlocks/CodeBlocks/MinGW";
  version = "25.03";
}
