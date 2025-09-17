{
  lib,
  __splicedPackages,
  wine,
  wine-mono,
  wineArch ? "wow64",
  runCommand,
  makeWrapper,
  nix-overlayfs,
}:

let
  pkgs = __splicedPackages;
  inherit (lib) makeExtensible;

  callPackageWithScope =
    scope: drv: args:
    lib.callPackageWith scope drv args;
  mkScope = scope: pkgs // scope;

  # newScope = extra: pkgs.lib.callPackageWith (pkgs // defaults // extra);
  # defaults = {
  #   inherit (nix-gaming) wine-mono wine-tkg wine-ge;
  #   wine = nix-gaming.wine-tkg;
  #   inherit nix-overlayfs;
  # };

  wineWrapped =
    runCommand "${wine}-${wineArch}"
      {
        nativeBuildInputs = [ makeWrapper ];
        meta.mainProgram = "wine";
      }
      ''
        makeWrapper ${lib.getExe wine} $out/bin/wine \
          --set WINEARCH "${wineArch}"
      '';

  packages =
    self:
    let
      defaultScope = mkScope self;
      callPackage = drv: args: callPackageWithScope defaultScope drv args;
    in
    rec {
      inherit nix-overlayfs callPackage;
      inherit wine-mono;
      wine = wineWrapped;

      wine-base-env = callPackage ./wine-base-env { };
      autohotkey = callPackage ./autohotkey { };
      crypt32-x86 = callPackage ./crypt32-x86 { };
      crypt32-x64 = callPackage ./crypt32-x64 { };
      dotnet-framework-4-8 = callPackage ./dotnet-framework-4-8 { };
      halo-custom-edition-1-00 = callPackage ./halo-custom-edition-1-00 { };
      halo-custom-edition-1-0-10 = callPackage ./halo-custom-edition-1-0-10 { };
      mingw = callPackage ./mingw { };
      msvcp60 = callPackage ./msvcp60 { };
      msxml4 = callPackage ./msxml4 { };
      notepad-plus-plus = callPackage ./notepad-plus-plus { };
      vlc = callPackage ./vlc { };
    };
in
makeExtensible packages
