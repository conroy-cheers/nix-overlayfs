# Author: Libor Štěpánek 2025
# example of a non-winpkgs package used with mkOverlayfsPackage
{
  self,
  pkgs,
}: let
  base = pkgs.stdenv.mkDerivation {
    pname = "2HOL";
    version = "20319";
    src = pkgs.fetchzip {
      url = "https://github.com/twohoursonelife/OneLife/releases/download/2HOL_v20319/2HOL_linux_v20319.zip";
      sha256 = "Q1NiGMMW/lBRvWXKwa5j19MzSdh7ibb1tVjexT7/rBQ=";
    };

    nativeBuildInputs = [
      pkgs.autoPatchelfHook
    ];

    buildInputs = with pkgs; [
      libGL
      libGLU
      SDL
      libpng
    ];

    installPhase = ''
      mkdir --parents $out
      cp --recursive * $out/
    '';
  };
in
  self.outputs.lib.mkOverlayfsPackage {
    basePackage = base;
    executablePath = "OneLife";
    executableName = "OneLife";
  }
