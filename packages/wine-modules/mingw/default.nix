{
  wine,
  overlayfsLib,
}:
overlayfsLib.mkWinpkgsPackage {
  inherit wine;
  packageName = "CodeBlocks/CodeBlocks/MinGW";
  version = "25.03";
}
