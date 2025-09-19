{
  lib,
  __splicedPackages,
  wine,
  wineArch ? "wow64",
  runCommand,
  makeWrapper,
  symlinkJoin,
  nix-overlayfs,
}:

let
  pkgs = __splicedPackages;
  inherit (lib) makeExtensible;

  callPackageWithScope =
    scope: drv: args:
    lib.callPackageWith scope drv args;
  mkScope = scope: pkgs // scope;

  wineExeName =
    {
      "win32" = "wine";
      "win64" = "wine64";
      "wow64" = "wine64";
    }
    .${wineArch};

  wineWrapped =
    runCommand "${wine}-${wineArch}"
      {
        nativeBuildInputs = [ makeWrapper ];

        meta.mainProgram = "wine-wrapped";
      }
      ''
        makeWrapper ${lib.getExe' wine wineExeName} $out/bin/wine-wrapped \
          --set WINEARCH "${wineArch}"
      '';
  wineCombo = symlinkJoin {
    pname = "${wine.pname}-${wineArch}-wrapped";
    inherit (wine) version;

    paths = [
      wine
      wineWrapped
    ];
    meta = wine.meta // {
      mainProgram = "wine-wrapped";
    };
  };

  packages =
    self:
    let
      defaultScope = mkScope self;
      callPackage = drv: args: callPackageWithScope defaultScope drv args;
    in
    rec {
      inherit nix-overlayfs callPackage;
      wine = wineCombo;

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
