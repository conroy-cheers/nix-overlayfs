{
  runtime,
  overlayfsLib,
}:
overlayfsLib.mkWinpkgsPackage {
  inherit runtime;
  packageName = "Microsoft/EdgeWebView2Runtime";
}
