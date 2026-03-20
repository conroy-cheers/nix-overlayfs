{
  runtime,
  overlayfsLib,
}:
overlayfsLib.mkWinpkgsPackage {
  inherit runtime;
  packageName = "CodeBlocks/CodeBlocks/MinGW";
  version = "25.03";
}
