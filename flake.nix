# Maintainer: Conroy Cheers <conroy@corncheese.org>
# Based on original work by Libor Štěpánek 2025
{
  description = "Composable, reproducible overlay-based packaging for Wine applications";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs?ref=nixos-unstable";
    };
    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-gaming-legacy = {
      url = "github:fufexan/nix-gaming?ref=97bd4c09876482bef50fdcea8ce3c55aa8892fbf";
    };
  };

  nixConfig = {
    allowInsecure = true;
    extra-substituters = [ "https://nix-gaming.cachix.org" ];
    extra-trusted-public-keys = [
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
    ];
  };

  outputs =
    {
      nixpkgs,
      ...
    }@inputs:
    let
      transposeAttrs =
        attrs:
        nixpkgs.lib.foldlAttrs (
          acc: outer: inner:
          nixpkgs.lib.recursiveUpdate acc (nixpkgs.lib.mapAttrs (k: v: { ${outer} = v; }) inner)
        ) { } attrs;

      generateSystems = (
        {
          self,
          nixpkgs,
          nix-gaming,
          nix-gaming-legacy,
        }@inputs:
        nixpkgs.lib.genAttrs [ "x86_64-linux" ] (
          system:
          let
            p = {
              inherit self;
              pkgs = nixpkgs.legacyPackages.${system};
              nix-gaming = nix-gaming.packages.${system};
              nix-gaming-legacy = nix-gaming-legacy.packages.${system};
            };

            lib = import ./lib {
              inherit (p) pkgs;
              inherit overlayfsLib;
            };

            packages = (
              import ./packages {
                inherit (p) pkgs nix-gaming nix-gaming-legacy;
                inherit overlayfsLib;
              }
            );

            appsListing = import ./apps {
              inherit overlayfsLib;
              inherit (packages) wineWow64Modules;
              inherit (p) pkgs;
            };

            checks = import ./tests {
              inherit overlayfsLib;
              inherit (p) pkgs;
            };

            overlayfsLib = lib;
          in
          {
            inherit lib checks packages;
            inherit (appsListing) apps;
          }
        )
      );
    in
    (transposeAttrs (generateSystems inputs))
    // {
      inherit inputs;
    };
}
