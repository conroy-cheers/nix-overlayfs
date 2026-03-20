{
  lib,
  pkgs,
  nix-gaming,
  nix-gaming-legacy,
  overlayfsLib,
}:
let
  isAarch64 = pkgs.stdenv.hostPlatform.isAarch64;
  versions = import ./versions.nix;
  toolchains = import ./toolchains.nix {
    inherit pkgs versions isAarch64;
  };
  runtimeCatalog = import ./runtime-catalog.nix {
    inherit
      lib
      pkgs
      nix-gaming
      nix-gaming-legacy
      overlayfsLib
      toolchains
      ;
  };
in
lib.optionalAttrs (!isAarch64) {
  inherit (runtimeCatalog)
    nativeWin32Modules
    nativeWow64Modules
    geWin32Modules
    tkgWow64Modules
    nativeModules
    ;
}
// lib.optionalAttrs isAarch64 {
  inherit (toolchains)
    llvmMingwArm64ec
    fexWineDlls
    nativeArm64ecWine
    nativeArm64ecWineWithFex
    ;
  inherit (runtimeCatalog)
    nativeModules
    x64FexModules
    ;
}
