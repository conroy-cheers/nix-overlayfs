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

    export NIX_OVERLAYFS_GRAPHICS_STACK=auto
    export __EGL_VENDOR_LIBRARY_FILENAMES=/nixgl/egl.json
    export LIBGL_DRIVERS_PATH=/nixgl/dri
    export GBM_BACKENDS_PATH=/nixgl/gbm
    export VK_DRIVER_FILES=/nixgl/vulkan.json
    export VK_LAYER_PATH=/nixgl/layers
    . ${bootstrapScript}
    test "$__EGL_VENDOR_LIBRARY_FILENAMES" = /nixgl/egl.json
    test "$LIBGL_DRIVERS_PATH" = /nixgl/dri
    test "$GBM_BACKENDS_PATH" = /nixgl/gbm
    test "$VK_DRIVER_FILES" = /nixgl/vulkan.json
    test "$VK_LAYER_PATH" = /nixgl/layers
  '';

  installPhase = "touch $out";
}
