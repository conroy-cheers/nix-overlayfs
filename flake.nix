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
    inputs@{
      self,
      nixpkgs,
      ...
    }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      mkPkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };
      pkgsFor = forAllSystems mkPkgsFor;
      packageSets = forAllSystems (system: pkgsFor.${system}.nix-overlayfs);
    in
    {
      overlays.default = final: prev: {
        nix-overlayfs = import ./pkgs/top-level {
          pkgs = final;
          inherit inputs;
        };
      };

      legacyPackages = forAllSystems (
        system:
        let
          lib = pkgsFor.${system}.lib;
        in
        {
          nix-overlayfs = lib.dontRecurseIntoAttrs packageSets.${system};
        }
      );

      packages = forAllSystems (system: packageSets.${system}.packages);

      apps = forAllSystems (system: packageSets.${system}.apps);

      lib = forAllSystems (system: packageSets.${system}.lib);

      checks = forAllSystems (
        system:
        import ./tests {
          pkgs = pkgsFor.${system};
          overlayfsLib = packageSets.${system}.lib;
        }
      );

      inherit inputs;
    };
}
