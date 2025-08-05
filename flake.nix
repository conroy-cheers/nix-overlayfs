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
      self,
      nixpkgs,
      nix-gaming,
    }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      inherit (self) inputs;

      lib = import ./lib { inherit self pkgs; };
      packages.x86_64-linux = import ./packages { inherit self pkgs; };

      # Generating the app entries based on the presence of the 'executableName' meta-attribute in the derivations
      apps.x86_64-linux =
        with self.inputs.nixpkgs.lib.attrsets;
        let
          derivations = filterAttrs (
            name: value: (isDerivation value) && (value.meta.executableName != "")
          ) self.outputs.packages.x86_64-linux;
        in
        concatMapAttrs (name: value: {
          ${name} = {
            type = "app";
            program = "${value}/bin/${value.meta.executableName}";
          };
        }) derivations;

      checks.x86_64-linux = import ./tests { inherit self pkgs; };
    };
}
