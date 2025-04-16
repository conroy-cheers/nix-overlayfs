# Author: Libor Štěpánek 2025
{
  description = "A proof of concept of an overlay-based writable layer for arbitrary packages";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in {
    lib = import ./lib {inherit self pkgs;};
    packages.x86_64-linux =
      import ./packages {inherit self pkgs;};

    # Generating the app entries based on the presence of the 'executableName' meta-attribute in the derivations
    apps.x86_64-linux = with self.inputs.nixpkgs.lib.attrsets; let
      derivations = filterAttrs (name: value: (isDerivation value) && (value.meta.executableName != "")) self.outputs.packages.x86_64-linux;
    in
      concatMapAttrs (name: value: {
        ${name} = {
          type = "app";
          program = "${value}/bin/${value.meta.executableName}";
        };
      })
      derivations;

    checks.x86_64-linux = import ./tests {inherit self pkgs;};
  };
}
