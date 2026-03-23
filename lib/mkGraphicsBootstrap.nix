{
  lib,
  patchelf,
}:
{
  runtime,
  modeEnvVar ? "NIX_OVERLAYFS_GRAPHICS_STACK",
  defaultMode ? "auto",
  systemDriverRoot ? "/run/opengl-driver",
}:
{
  extraPreLaunchCommands = ''
    nix_overlayfs_join_colon_paths() {
      local joined=""
      local path
      for path in "$@"; do
        if [ -n "$path" ] && [ -e "$path" ]; then
          if [ -n "$joined" ]; then
            joined="$joined:$path"
          else
            joined="$path"
          fi
        fi
      done
      printf '%s' "$joined"
    }

    nix_overlayfs_graphics_stack_var=${lib.escapeShellArg modeEnvVar}
    nix_overlayfs_default_graphics_stack=${lib.escapeShellArg defaultMode}
    nix_overlayfs_system_driver_root=${lib.escapeShellArg systemDriverRoot}
    nix_overlayfs_graphics_stack="''${!nix_overlayfs_graphics_stack_var:-$nix_overlayfs_default_graphics_stack}"
    nix_overlayfs_driver_root=""

    case "$nix_overlayfs_graphics_stack" in
      auto)
        ;;
      system)
        if [ -d "$nix_overlayfs_system_driver_root" ]; then
          nix_overlayfs_driver_root="$nix_overlayfs_system_driver_root"
        else
          echo "warning: $nix_overlayfs_graphics_stack_var=system requested but $nix_overlayfs_system_driver_root is unavailable; leaving graphics discovery to the host environment" >&2
          nix_overlayfs_graphics_stack=auto
        fi
        ;;
      *)
        echo "warning: unknown $nix_overlayfs_graphics_stack_var=$nix_overlayfs_graphics_stack, expected auto|system; falling back to auto" >&2
        nix_overlayfs_graphics_stack=auto
        ;;
    esac

    nix_overlayfs_wine_rpath="$(${patchelf}/bin/patchelf --print-rpath ${runtime.toolsPackage}/bin/.wine)"
    nix_overlayfs_graphics_lib=""
    if [ "$nix_overlayfs_graphics_stack" = system ] && [ -n "$nix_overlayfs_driver_root" ] && [ -d "$nix_overlayfs_driver_root/lib" ]; then
      nix_overlayfs_graphics_lib="$nix_overlayfs_driver_root/lib"
    fi

    export LD_LIBRARY_PATH="''${nix_overlayfs_graphics_lib:+$nix_overlayfs_graphics_lib:}''${nix_overlayfs_wine_rpath:+$nix_overlayfs_wine_rpath:}''${LD_LIBRARY_PATH:-}"
    export LD_LIBRARY_PATH="''${LD_LIBRARY_PATH%:}"

    if [ "$nix_overlayfs_graphics_stack" = auto ]; then
      unset __EGL_VENDOR_LIBRARY_FILENAMES
      unset LIBGL_DRIVERS_PATH
      unset GBM_BACKENDS_PATH
      unset VK_DRIVER_FILES
      unset VK_LAYER_PATH
    else
      nix_overlayfs_egl_vendor_files="$(nix_overlayfs_join_colon_paths "$nix_overlayfs_driver_root"/share/glvnd/egl_vendor.d/*.json)"
      if [ -n "$nix_overlayfs_egl_vendor_files" ]; then
        export __EGL_VENDOR_LIBRARY_FILENAMES="$nix_overlayfs_egl_vendor_files"
      else
        unset __EGL_VENDOR_LIBRARY_FILENAMES
      fi

      if [ -d "$nix_overlayfs_driver_root/lib/dri" ]; then
        export LIBGL_DRIVERS_PATH="$nix_overlayfs_driver_root/lib/dri"
      else
        unset LIBGL_DRIVERS_PATH
      fi

      if [ -d "$nix_overlayfs_driver_root/lib/gbm" ]; then
        export GBM_BACKENDS_PATH="$nix_overlayfs_driver_root/lib/gbm"
      else
        unset GBM_BACKENDS_PATH
      fi

      nix_overlayfs_vk_driver_files="$(nix_overlayfs_join_colon_paths "$nix_overlayfs_driver_root"/share/vulkan/icd.d/*.json)"
      if [ -n "$nix_overlayfs_vk_driver_files" ]; then
        export VK_DRIVER_FILES="$nix_overlayfs_vk_driver_files"
      else
        unset VK_DRIVER_FILES
      fi

      nix_overlayfs_vk_layer_paths="$(nix_overlayfs_join_colon_paths "$nix_overlayfs_driver_root/share/vulkan/explicit_layer.d" "$nix_overlayfs_driver_root/share/vulkan/implicit_layer.d")"
      if [ -n "$nix_overlayfs_vk_layer_paths" ]; then
        export VK_LAYER_PATH="$nix_overlayfs_vk_layer_paths"
      else
        unset VK_LAYER_PATH
      fi
    fi
  '';
}
