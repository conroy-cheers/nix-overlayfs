{
  pkgs,
  nix-gaming,
  nix-overlayfs,
}:

let
  newScope = extra: pkgs.lib.callPackageWith (pkgs // defaults // extra);
  defaults = {
    inherit (nix-gaming) wine-mono wine-tkg wine-ge;
    wine = nix-gaming.wine-tkg;
    inherit nix-overlayfs;
  };
in
pkgs.lib.makeScope newScope (
  self: with self; {
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
  }
)
