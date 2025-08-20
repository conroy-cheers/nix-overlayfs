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
      crypt32-x86 = callPackage ./crypt32-x86 { };
      crypt32-x64 = callPackage ./crypt32-x64 { };
      dotnet-framework-4-8 = callPackage ./dotnet-framework-4-8 { };
      wine-dxvk = callPackage ./wine-dxvk { };
      halo-custom-edition = callPackage ./halo-custom-edition { };
      mfc42 = callPackage ./mfc42 { };
      mingw = callPackage ./mingw { };
      msvcp60 = callPackage ./msvcp60 { };
      msxml4 = callPackage ./msxml4 { };
      notepad-plus-plus = callPackage ./notepad-plus-plus { };
      vlc = callPackage ./vlc { };
    };
in
makeExtensible packages
