{
  pkgs,
  overlayfsLib,
}:
let
  runtime = pkgs.nix-overlayfs.moduleScopes.nativeModules.runtime;
  bootstrap = overlayfsLib.mkGraphicsBootstrap { inherit runtime; };
  bootstrapScript = pkgs.writeText "graphics-bootstrap.sh" bootstrap.extraPreLaunchCommands;
in
pkgs.stdenv.mkDerivation {
  pname = "graphics-bootstrap-test";
  version = "1.0.0";
  unpackPhase = "true";
  nativeBuildInputs = [ pkgs.gnugrep ];
  buildPhase = ''
    grep -F "NIX_OVERLAYFS_GRAPHICS_STACK" ${bootstrapScript}
    grep -F "/run/opengl-driver" ${bootstrapScript}
    grep -F "${pkgs.patchelf}/bin/patchelf --print-rpath ${runtime.toolsPackage}/bin/.wine" ${bootstrapScript}

    ! grep -F "HALO_GL_STACK" ${bootstrapScript}
    ! grep -F "asahi" ${bootstrapScript}
    ! grep -F "50_mesa" ${bootstrapScript}
    ! grep -F "asahi_icd" ${bootstrapScript}
    ! grep -F "unset WAYLAND_DISPLAY" ${bootstrapScript}
  '';

  installPhase = "touch $out";
}
