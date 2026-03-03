{
  wine,
  overlayfsLib,
}:
overlayfsLib.mkWinpkgsPackage {
  inherit wine;
  packageName = "Microsoft/EdgeWebView2Runtime";
}
