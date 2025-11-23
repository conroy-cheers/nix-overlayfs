{
  callPackage,
  overlayfsLib,
}:
{
  wineBasePkg,
  wineArch,
}:
let
  mkOverlayfsWrappedWine = callPackage ./mk-overlayfs-wrapped-wine { };

  overlayfsWrappedWine = mkOverlayfsWrappedWine {
    wine = wineBasePkg;
    inherit wineArch;
  };

  wineModules = callPackage ./wine-modules {
    inherit overlayfsLib;
    wine = overlayfsWrappedWine.overrideAttrs (
      {
        passthru ? { },
        ...
      }:
      {
        passthru = passthru // {
          inherit (wineModules) wine-base-env autohotkey;
        };
      }
    );
  };
in
wineModules
