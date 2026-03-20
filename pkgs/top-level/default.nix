{
  pkgs,
  inputs,
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  overlayfsLib = import ../../lib {
    inherit pkgs overlayfsLib;
  };
  packageScopes = import ../../packages {
    inherit (pkgs) lib;
    inherit pkgs overlayfsLib;
    nix-gaming = inputs.nix-gaming.packages.${system};
    nix-gaming-legacy = inputs.nix-gaming-legacy.packages.${system};
  };
  appsListing = import ../../apps {
    inherit pkgs packageScopes overlayfsLib;
  };
  derivationPackageScopes = pkgs.lib.filterAttrs (_: v: pkgs.lib.isDerivation v) packageScopes;
in
{
  lib = overlayfsLib;
  packages = derivationPackageScopes // appsListing.packages;
  apps = appsListing.apps;

  moduleScopes = packageScopes;
  packageVariants = appsListing.packageVariants;
  appVariants = appsListing.appVariants;
}
