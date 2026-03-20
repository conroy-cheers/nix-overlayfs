{
  pkgs,
  overlayfsLib,
}:
let
  mkNotepadPlusPlus =
    {
      modules,
      binaryArch ? "x64",
    }:
    pkgs.callPackage ./notepad-plus-plus {
      inherit modules overlayfsLib binaryArch;
    };
in
{
  hello-x64 = {
    variants = {
      x64 = modules: pkgs.callPackage ./hello-x64 {
        inherit overlayfsLib modules;
      };
    };
  };

  notepad-plus-plus = {
    variants = {
      x64 = modules: mkNotepadPlusPlus { inherit modules; };
      arm64 = modules: mkNotepadPlusPlus {
        inherit modules;
        binaryArch = "arm64";
      };
    };
  };

  vlc = {
    variants = {
      x64 = modules: pkgs.callPackage ./vlc {
        inherit overlayfsLib modules;
      };
    };
  };
}
