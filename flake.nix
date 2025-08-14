# Author: Libor Štěpánek 2025
{
  description = "A proof of concept of an overlay-based writable layer for arbitrary packages";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs?ref=nixos-unstable";
    };
    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      # inputs.nixpkgs.follows = "nixpkgs";
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
        }@inputs:
        nixpkgs.lib.genAttrs [ "x86_64-linux" ] (
          system:
          let
            p = {
              inherit self;
              pkgs = nixpkgs.legacyPackages.${system};
              nix-gaming = nix-gaming.packages.${system};
            };

            lib = import ./lib {
              inherit (p) pkgs nix-gaming;
              inherit nix-overlayfs;
            };

            packages = (
              import ./packages {
                inherit (p) pkgs nix-gaming;
                inherit nix-overlayfs;
              }
            );

            # Generate the app entries based on the presence of the 'executableName' meta-attribute in the derivations
            apps =
              with p.pkgs.lib.attrsets;
              let
                derivations = filterAttrs (
                  name: value: (isDerivation value) && (value.meta.executableName != "")
                ) packages;
              in
              concatMapAttrs (name: value: {
                ${name} = {
                  type = "app";
                  program = "${value}/bin/${value.meta.executableName}";
                };
              }) derivations;

            checks = import ./tests {
              inherit nix-overlayfs;
              inherit (p) pkgs;
            };

            nix-overlayfs = packages // {
              inherit lib;
            };
          in
          {
            inherit
              lib
              apps
              checks
              ;

            packages = with nixpkgs.lib; (filterAttrs (n: pkg: isDerivation pkg) packages);
          }
        )
      );
    in
    transposeAttrs (generateSystems inputs);

  # {
  #   inherit (self) inputs;

  #   lib = import ./lib { inherit self pkgs; };
  #   packages.x86_64-linux = import ./packages { inherit self pkgs; };

  #   # Generating the app entries based on the presence of the 'executableName' meta-attribute in the derivations
  #   apps.x86_64-linux =
  #     with self.inputs.nixpkgs.lib.attrsets;
  #     let
  #       derivations = filterAttrs (
  #         name: value: (isDerivation value) && (value.meta.executableName != "")
  #       ) self.outputs.packages.x86_64-linux;
  #     in
  #     concatMapAttrs (name: value: {
  #       ${name} = {
  #         type = "app";
  #         program = "${value}/bin/${value.meta.executableName}";
  #       };
  #     }) derivations;

  #   checks.x86_64-linux = import ./tests { inherit self pkgs; };
  # };
}
