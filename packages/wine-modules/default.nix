{
  lib,
  __splicedPackages,
  wine,
  overlayfsLib,
}:

let
  pkgs = __splicedPackages;
  inherit (lib) makeExtensible;

  callPackageWithScope =
    scope: drv: args:
    lib.callPackageWith scope drv args;
  mkScope = scope: pkgs // scope;

  packages =
    self:
    let
      defaultScope = mkScope self;
      callPackage = drv: args: callPackageWithScope defaultScope drv args;
    in
    rec {
      inherit overlayfsLib callPackage wine;

      wine-base-env = callPackage ./wine-base-env { };
      autohotkey = callPackage ./autohotkey { };
      crypt32 = callPackage ./crypt32 { };
      dotnet-framework-4-8 = callPackage ./dotnet-framework-4-8 { };
      fonts = callPackage ./fonts { };
      wine-dxvk = callPackage ./wine-dxvk { };
      mfc42 = callPackage ./mfc42 { };
      mingw = callPackage ./mingw { };
      msvcp60 = callPackage ./msvcp60 { };
      msxml4 = callPackage ./msxml4 { };
      msxml6 = callPackage ./msxml6 { };
      vcrun2022 = callPackage ./vcrun2022 { };
      vlc = callPackage ./vlc { };
      webview2 = callPackage ./webview2 { };
      win11 = callPackage ./win11 { };
    };
in
makeExtensible packages
