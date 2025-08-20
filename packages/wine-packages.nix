{
  callPackage,
  overlayfsLib,
}:
{
  wineBasePkg,
  wineArch,
}:
let
  wineWrapped = callPackage ./wine/default.nix {
    wine = wineBasePkg;
    inherit wineArch;
  };

  wineModules = callPackage ./wine-modules {
    inherit overlayfsLib;
    wine = wineWrapped.overrideAttrs (
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
