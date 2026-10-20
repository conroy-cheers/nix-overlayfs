# Maintainer: Conroy Cheers <conroy@corncheese.org>
# Based on original work by Libor Štěpánek 2025
{
  pkgs,
  stdenv,
  overlayfsLib,
}:
{
  basePackage,
  workingDirectory ? null,
  executablePath,
  executableName,
  overlayDependencies ? [ ],
  extraEnvCommands ? "",
  extraPreLaunchCommands ? "",
  extraPostLaunchCommands ? "",
  launchProgram ? "",
  session ? null,
  basePackageName ? basePackage.pname,
  hostIntegration ? true,
  namespaceMode ? "auto",
  processTerminationTimeout ? 5,
  stateMode ? "persistent",
  urlSchemes ? [ ],
  urlSchemeDiscoveryCommands ? "",
  urlSchemeRegistryCommands ? "",
  urlSchemeOpenCommands ? "",
  entrypointWrapper ? (entrypoint: ''exec ${entrypoint} "$@"''),
  passthru ? { },
}:
let
  lib = pkgs.lib;
  _checkUrlSchemes =
    if builtins.isList urlSchemes then true else throw "urlSchemes must be a list of URI scheme names";
  _checkNamespaceMode =
    if
      builtins.elem namespaceMode [
        "auto"
        "required"
        "direct"
      ]
    then
      true
    else
      throw "namespaceMode must be one of: auto, required, direct";
  _checkStateMode =
    if
      builtins.elem stateMode [
        "persistent"
        "ephemeral"
      ]
    then
      true
    else
      throw "stateMode must be one of: persistent, ephemeral";
  _checkProcessTerminationTimeout =
    if builtins.isInt processTerminationTimeout && processTerminationTimeout >= 0 then
      true
    else
      throw "processTerminationTimeout must be a non-negative integer number of seconds";
  _checkHostIntegration =
    if
      hostIntegration
      || (
        urlSchemes == [ ]
        && urlSchemeDiscoveryCommands == ""
        && urlSchemeRegistryCommands == ""
        && urlSchemeOpenCommands == ""
      )
    then
      true
    else
      throw "URL scheme integration requires hostIntegration = true";
  explicitUrlSchemeCommands = lib.concatMapStringsSep "\n" (
    scheme: "printf '%s\\n' ${lib.escapeShellArg scheme}"
  ) urlSchemes;
  runtimeSupervisor = pkgs.callPackage ./runtime-supervisor.nix { };
in
assert _checkUrlSchemes;
assert _checkNamespaceMode;
assert _checkStateMode;
assert _checkProcessTerminationTimeout;
assert _checkHostIntegration;
stdenv.mkDerivation {
  pname = basePackage.pname + "-overlay";
  version = basePackage.version;
  meta.executableName = executableName;
  unpackPhase = "true";

  buildPhase =
    let
      desktopId = "${executableName}-nix-overlayfs-url-handler.desktop";
      urlSchemeRegistrationCommands = lib.optionalString hostIntegration ''
                  nix_overlayfs_discover_url_schemes() {
          {
            :
            ${explicitUrlSchemeCommands}
            ${urlSchemeDiscoveryCommands}
          } \
            | ${pkgs.gawk}/bin/awk '
                {
                  scheme = tolower($0)
                  if (scheme !~ /^[a-z][a-z0-9+.-]*$/) next
                  if (scheme == "http" || scheme == "https" || scheme == "ftp" || scheme == "mailto") next
                  if (!seen[scheme]++) print scheme
                }
              '
        }

        nix_overlayfs_register_url_handlers() {
          local applications_dir="$XDG_DATA_HOME/applications"
          local desktop_file="$applications_dir/${desktopId}"
          local handler_script="$state_dir/open-url"
          local mime_types=""
          local existing_default=""
          local scheme=""

          mkdir -p "$applications_dir"
          nix_overlayfs_url_schemes_file="$state_dir/url-schemes"
          nix_overlayfs_discover_url_schemes > "$nix_overlayfs_url_schemes_file"

          [ -s "$nix_overlayfs_url_schemes_file" ] || return 0

          printf '%s\n' \
            '#!${pkgs.bash}/bin/bash' \
            'exec __STOREPATH__/bin/${executableName} --nix-overlayfs-open-url "$@"' \
            > "$handler_script"
          chmod 755 "$handler_script"

          while IFS= read -r scheme; do
            mime_types="$mime_types""x-scheme-handler/$scheme;"
          done < "$nix_overlayfs_url_schemes_file"

          printf '%s\n' \
            '[Desktop Entry]' \
            'Type=Application' \
            'Name=${executableName} URL Handler' \
            'NoDisplay=true' \
            "Exec=$handler_script %u" \
            "MimeType=$mime_types" \
            > "$desktop_file"

          ${pkgs.desktop-file-utils}/bin/update-desktop-database "$applications_dir" >/dev/null 2>&1 || true

          while IFS= read -r scheme; do
            existing_default="$(${pkgs.xdg-utils}/bin/xdg-mime query default "x-scheme-handler/$scheme" 2>/dev/null || true)"
            if [ -n "$existing_default" ] && [ "$existing_default" != "${desktopId}" ]; then
              echo "warning: x-scheme-handler/$scheme was registered to $existing_default; setting ${desktopId} for ${basePackageName}" >&2
            fi
            ${pkgs.xdg-utils}/bin/xdg-mime default '${desktopId}' "x-scheme-handler/$scheme" >/dev/null 2>&1 || true
          done < "$nix_overlayfs_url_schemes_file"
                  }

                  nix_overlayfs_record_session_env() {
                    local env_file="$state_dir/session-env"
                    local env_file_tmp="$env_file.$$"
                    local name=""
                    local value=""

                    : > "$env_file_tmp"
                    for name in \
                      DBUS_SESSION_BUS_ADDRESS \
                      DISPLAY \
                      DXVK_LOG_LEVEL \
                      DXVK_STATE_CACHE \
                      LD_LIBRARY_PATH \
                      MESA_VK_IGNORE_CONFORMANCE_WARNING \
                      PATH \
                      RIVE_WINE_DISPLAY_DRIVER \
                      RIVE_WINE_DPI_EFFECTIVE \
                      RIVE_WINE_DPI_SCALE \
                      RIVE_WINE_WAYLAND_SURFACE_SCALE \
                      RIVE_WINE_WAYLAND_SURFACE_SCALE_EFFECTIVE \
                      VK_DRIVER_FILES \
                      VK_ICD_FILENAMES \
                      VK_LAYER_PATH \
                      WAYLAND_DISPLAY \
                      WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS \
                      WINEPREFIX \
                      WINEARCH \
                      WINEDEBUG \
                      WINEDLLPATH \
                      WINEDLLOVERRIDES \
                      WINEESYNC \
                      WINEFSYNC \
                      XAUTHORITY \
                      XDG_CURRENT_DESKTOP \
                      XDG_RUNTIME_DIR \
                      XDG_SESSION_TYPE
                    do
                      value="''${!name-}"
                      if [ -n "$value" ]; then
                        printf '%s=%q\n' "$name" "$value" >> "$env_file_tmp"
                      fi
                    done
                    mv "$env_file_tmp" "$env_file"
                  }

                  nix_overlayfs_load_session_env() {
                    if [ -f "$state_dir/session-env" ]; then
                      # shellcheck disable=SC1091
                      set -a
                      . "$state_dir/session-env"
                      set +a
                    fi
                  }

                  nix_overlayfs_enqueue_url_request() {
                    local request_file=""

                    mkdir -p "$state_dir/open-requests"
                    request_file="$(mktemp "$state_dir/open-requests/request.XXXXXXXXXX")"
                    printf '%s\n' "$callback_url" > "$request_file"
                  }

                  nix_overlayfs_active_session_exists() {
                    local candidate=""
                    local cmdline_file=""
                    local cmdline=""

                    if [ -n "$active_pid" ] \
                      && kill -0 "$active_pid" 2>/dev/null \
                      && grep -F " $active_overlay " "/proc/$active_pid/mountinfo" >/dev/null 2>&1; then
                      return 0
                    fi

                    for cmdline_file in /proc/[0-9]*/cmdline; do
                      [ -r "$cmdline_file" ] || continue
                      cmdline="$(tr '\0' ' ' < "$cmdline_file" 2>/dev/null || true)"
                      for candidate in \
                        "$active_overlay/${executablePath}" \
                        "$active_overlay/${lib.removePrefix "/" executablePath}"
                      do
                        if [ -n "$cmdline" ] && [[ "$cmdline" == *"$candidate"* ]]; then
                          return 0
                        fi
                      done
                    done

                    return 1
                  }

      '';
      overlayProcessCommands = ''
        nix_overlayfs_overlay_process_exists() {
          local overlay_root="$1"
          local candidate=""
          local cmdline_file=""
          local cmdline=""

          for cmdline_file in /proc/[0-9]*/cmdline; do
            [ -r "$cmdline_file" ] || continue
            cmdline="$(tr '\0' ' ' < "$cmdline_file" 2>/dev/null || true)"
            for candidate in \
              "$overlay_root/${executablePath}" \
              "$overlay_root/${lib.removePrefix "/" executablePath}"
            do
              if [ -n "$cmdline" ] && [[ "$cmdline" == *"$candidate"* ]]; then
                return 0
              fi
            done
          done

          return 1
        }
      '';
      activeUrlSchemeOpenInvocation = "nix_overlayfs_enqueue_url_request";
      urlSchemeCommand =
        if urlSchemeOpenCommands != "" then
          ''env HOME="$HOME" WINEPREFIX="$tempdir/overlay" WINEARCH="$WINEARCH" WINEDEBUG="$WINEDEBUG" callback_url="$callback_url" active_overlay="$tempdir/overlay" tempdir="$tempdir" ${pkgs.bash}/bin/bash -c ${lib.escapeShellArg urlSchemeOpenCommands}''
        else
          ''env HOME="$HOME" WINEPREFIX="$tempdir/overlay" WINEARCH="$WINEARCH" WINEDEBUG="$WINEDEBUG" ${launchProgram} "$tempdir/overlay/${executablePath}" "$callback_url"'';
      urlSchemeOpenInvocation = ''
        if [ "''${NIX_OVERLAYFS_DIRECT_MODE:-0}" = 1 ]; then
          (
            ${lib.optionalString (
              workingDirectory != null
            ) ''cd "$tempdir/overlay/${workingDirectory}" || exit''}
            ${urlSchemeCommand}
          )
        else
          ${pkgs.util-linux}/bin/unshare --map-user="$originalUser" ${
            if workingDirectory != null then "--wd \"$tempdir/overlay/${workingDirectory}\"" else ""
          } ${urlSchemeCommand}
        fi
      '';
      # the script which serves as a stand-in for the executable specified by 'executablePath' and named as 'executableName'
      entryScript = pkgs.writeShellScript "runApp" ''

        # Checking the location for the writable layer
        if [ -z ''${HOME+x} ]; then
            exit 1
        fi

        export originalUser="''${USER:-$(${pkgs.coreutils}/bin/id -un)}"
        ${
          if stateMode == "ephemeral" then
            ''
              runtime_tmp_root="''${XDG_RUNTIME_DIR:-''${TMPDIR:-/tmp}}"
              export tmpbase="$runtime_tmp_root/nix-overlayfs"
              mkdir --parents "$tmpbase" || exit 1
              chmod 700 "$tmpbase" || exit 1

              export tempdir=$(mktemp -d -p "$tmpbase")
              export TMPDIR="$tempdir/tmp"
              export XDG_DATA_HOME="$tempdir/xdg-data"
              export XDG_CACHE_HOME="$tempdir/xdg-cache"
              export appdir="$tempdir/upper"
              mkdir --parents \
                "$TMPDIR" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$appdir" || exit 1
            ''
          else
            ''
              if [ -z ''${XDG_DATA_HOME+x} ]; then
                  XDG_DATA_HOME="$HOME/.local/share"
              fi

              if [ -z ''${XDG_CACHE_HOME+x} ]; then
                  XDG_CACHE_HOME="$HOME/.cache"
              fi

              export XDG_DATA_HOME XDG_CACHE_HOME
              export appdir="$XDG_DATA_HOME/${basePackageName}"
              export tmpbase="$XDG_CACHE_HOME/nix-overlayfs/tmp"

              mkdir --parents "$appdir" "$tmpbase" || exit 1
              chmod 700 "$tmpbase" || exit 1

              export tempdir=$(mktemp -d -p "$tmpbase")
              export TMPDIR="$tempdir/tmp"
              mkdir --parents "$TMPDIR" || exit 1
            ''
        }

        ${extraEnvCommands}

        state_dir="$appdir/.nix-overlayfs"
        host_browser_request_dir="$state_dir/host-browser-requests"
        ${lib.optionalString hostIntegration ''
          export NIX_OVERLAYFS_HOST_OPEN_DIR="$host_browser_request_dir"
          nix_overlayfs_host_open_dir_win="Z:$host_browser_request_dir"
          export NIX_OVERLAYFS_HOST_OPEN_DIR_WIN="''${nix_overlayfs_host_open_dir_win//\//\\}"
        ''}
        nix_overlayfs_host_browser_broker_pid=""

        nix_overlayfs_load_session_env() {
          if [ -f "$state_dir/session-env" ]; then
            # shellcheck disable=SC1091
            set -a
            . "$state_dir/session-env"
            set +a
          fi
        }

        nix_overlayfs_enqueue_url_request() {
          local request_file=""

          mkdir -p "$state_dir/open-requests"
          request_file="$(mktemp "$state_dir/open-requests/request.XXXXXXXXXX")"
          printf '%s\n' "$callback_url" > "$request_file"
        }

        nix_overlayfs_active_session_exists() {
          local candidate=""
          local cmdline_file=""
          local cmdline=""

          if [ -n "$active_pid" ] \
            && kill -0 "$active_pid" 2>/dev/null \
            && grep -F " $active_overlay " "/proc/$active_pid/mountinfo" >/dev/null 2>&1; then
            return 0
          fi

          for cmdline_file in /proc/[0-9]*/cmdline; do
            [ -r "$cmdline_file" ] || continue
            cmdline="$(tr '\0' ' ' < "$cmdline_file" 2>/dev/null || true)"
            for candidate in \
              "$active_overlay/${executablePath}" \
              "$active_overlay/${lib.removePrefix "/" executablePath}"
            do
              if [ -n "$cmdline" ] && [[ "$cmdline" == *"$candidate"* ]]; then
                return 0
              fi
            done
          done

          return 1
        }

        nix_overlayfs_process_host_browser_requests() {
          local processing_file=""
          local request_file=""
          local target_url=""

          mkdir -p "$host_browser_request_dir"
          for request_file in "$host_browser_request_dir"/request.*; do
            [ -f "$request_file" ] || continue
            case "$request_file" in
              *.tmp|*.processing.*)
                continue
                ;;
            esac

            processing_file="$request_file.processing.$$"
            if ! mv "$request_file" "$processing_file" 2>/dev/null; then
              continue
            fi

            target_url="$(cat "$processing_file" 2>/dev/null || true)"
            rm -f "$processing_file"
            [ -n "$target_url" ] || continue

            if ! ${
              if hostIntegration then lib.getExe overlayfsLib.hostUrlOpener else "${pkgs.coreutils}/bin/false"
            } --direct "$target_url"; then
              echo "warning: failed to open URL with host browser: $target_url" >&2
            fi
          done
        }

        nix_overlayfs_host_browser_broker() {
          while [ ! -e "$host_browser_request_dir/.stop" ]; do
            nix_overlayfs_process_host_browser_requests
            sleep 0.2
          done
          nix_overlayfs_process_host_browser_requests
        }

        nix_overlayfs_start_host_browser_broker() {
          mkdir -p "$host_browser_request_dir"
          rm -f "$host_browser_request_dir/.stop"
          nix_overlayfs_host_browser_broker &
          nix_overlayfs_host_browser_broker_pid="$!"
        }

        nix_overlayfs_stop_host_browser_broker() {
          [ -n "$nix_overlayfs_host_browser_broker_pid" ] || return 0
          touch "$host_browser_request_dir/.stop"
          wait "$nix_overlayfs_host_browser_broker_pid" 2>/dev/null || true
          nix_overlayfs_host_browser_broker_pid=""
          rm -f "$host_browser_request_dir/.stop"
        }

        nix_overlayfs_forward_signal() {
          local signal_name="$1"
          if [ -n "$nix_overlayfs_supervisor_pid" ]; then
            kill -s "$signal_name" "$nix_overlayfs_supervisor_pid" 2>/dev/null || true
          fi
        }

        nix_overlayfs_entry_cleanup() {
          local status=$?
          trap - EXIT HUP INT TERM
          if [ -n "$nix_overlayfs_supervisor_pid" ]; then
            kill -TERM "$nix_overlayfs_supervisor_pid" 2>/dev/null || true
            wait "$nix_overlayfs_supervisor_pid" 2>/dev/null || true
            nix_overlayfs_supervisor_pid=""
          fi
          nix_overlayfs_stop_host_browser_broker || true
          if [ -d "$tempdir/overlay" ]; then
            ${pkgs.fuse3}/bin/fusermount3 -u "$tempdir/overlay" 2>/dev/null \
              || ${pkgs.fuse3}/bin/fusermount3 -uz "$tempdir/overlay" 2>/dev/null \
              || ${pkgs.util-linux}/bin/umount -l "$tempdir/overlay" 2>/dev/null \
              || true
          fi
          if ${pkgs.util-linux}/bin/mountpoint -q "$tempdir/overlay"; then
            echo "warning: failed to unmount nix-overlayfs runtime at $tempdir/overlay" >&2
          else
            rm -r "$tempdir"
            rmdir "$tmpbase" 2>/dev/null || true
          fi
          exit "$status"
        }

        ${lib.optionalString hostIntegration ''
          if [ "''${1:-}" = "--nix-overlayfs-open-url" ]; then
            callback_url="''${2:-}"
            if [ -z "$callback_url" ]; then
              echo "Missing URL for --nix-overlayfs-open-url" >&2
              exit 2
            fi

            active_pid=""
            active_overlay=""
            if [ -f "$state_dir/session.pid" ] && [ -f "$state_dir/overlay-root" ]; then
              active_pid="$(cat "$state_dir/session.pid" 2>/dev/null || true)"
              active_overlay="$(cat "$state_dir/overlay-root" 2>/dev/null || true)"
            fi

            if [ -n "$active_pid" ] \
              && [ -n "$active_overlay" ] \
              && [ -d "$active_overlay" ] \
              && nix_overlayfs_active_session_exists; then
              nix_overlayfs_load_session_env
              ${activeUrlSchemeOpenInvocation}
              exit $?
            fi
          fi
        ''}

        mkdir --parents "$appdir" "$tempdir/bind" "$tempdir/overlay" || exit 1
        nix_overlayfs_supervisor_pid=""
        ${lib.optionalString hostIntegration "nix_overlayfs_start_host_browser_broker"}
        trap nix_overlayfs_entry_cleanup EXIT
        trap 'nix_overlayfs_forward_signal HUP' HUP
        trap 'nix_overlayfs_forward_signal INT' INT
        trap 'nix_overlayfs_forward_signal TERM' TERM

        namespace_mode="''${NIX_OVERLAYFS_NAMESPACE_MODE:-${namespaceMode}}"
        case "$namespace_mode" in
          auto|required|direct)
            ;;
          *)
            echo "error: NIX_OVERLAYFS_NAMESPACE_MODE must be one of: auto, required, direct" >&2
            exit 2
            ;;
        esac

        if [ "$namespace_mode" = auto ]; then
          namespace_probe_log="$tempdir/unshare-probe.log"
          if ${pkgs.util-linux}/bin/unshare --map-root-user --mount true 2>"$namespace_probe_log"; then
            namespace_mode=required
          elif grep -Eq '(uid_map|gid_map).*(Operation not permitted|Permission denied)|(unshare failed:|cannot create user namespace:).*(Operation not permitted|Permission denied)' "$namespace_probe_log"; then
            echo "warning: nix-overlayfs: user/mount namespaces are unavailable; using direct FUSE mode" >&2
            sed 's/^/warning: nix-overlayfs: unshare: /' "$namespace_probe_log" >&2
            namespace_mode=direct
          else
            echo "error: nix-overlayfs: namespace capability probe failed unexpectedly" >&2
            cat "$namespace_probe_log" >&2
            exit 1
          fi
        fi

        process_termination_timeout="''${NIX_OVERLAYFS_PROCESS_TERMINATION_TIMEOUT:-${toString processTerminationTimeout}s}"
        supervisor=(
          ${runtimeSupervisor}/bin/nix-overlayfs-runtime-supervisor
          --term-timeout "$process_termination_timeout"
          --mountpoint "$tempdir/overlay"
          --label ${lib.escapeShellArg basePackageName}
          --
          "__STOREPATH__/libexec/${executableName}-setupEnv.sh"
        )

        if [ "$namespace_mode" = direct ]; then
          export NIX_OVERLAYFS_DIRECT_MODE=1
          "''${supervisor[@]}" "$@" &
        else
          unset NIX_OVERLAYFS_DIRECT_MODE
          ${pkgs.util-linux}/bin/unshare --map-root-user --mount "''${supervisor[@]}" "$@" &
        fi
        nix_overlayfs_supervisor_pid=$!
        while :; do
          wait "$nix_overlayfs_supervisor_pid"
          launch_status=$?
          if ! jobs -pr | ${pkgs.gnugrep}/bin/grep -Fxq "$nix_overlayfs_supervisor_pid"; then
            break
          fi
        done
        nix_overlayfs_supervisor_pid=""
        exit "$launch_status"
      '';

      entryScriptWrapper = pkgs.writeShellScript "runApp-wrapped" (
        entrypointWrapper "__STOREPATH__/bin/${executableName}-unwrapped"
      );

      # The environment script, launched from the entry script
      envScript =
        {
          executablePath,
          overlayDependencies,
          extraPreLaunchCommands,
        }:
        let
          deps = builtins.map (x: "\"" + x + "\"") overlayDependencies;
          renderEnvExports =
            env: builtins.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (n: v: "export ${n}=${v}") env);
        in
        pkgs.writeShellScript "runEnv" ''
          deps=(${pkgs.lib.strings.concatStringsSep " " deps});
          lowerdirs="__STOREPATH__/basePackage";
          overlay_workdir_parent="$(${pkgs.coreutils}/bin/dirname "$appdir")"
          overlay_workdir_base=".$(${pkgs.coreutils}/bin/basename "$appdir").nix-overlayfs-work"
          overlay_workdir="$overlay_workdir_parent/$overlay_workdir_base"

          for ((i = ''${#deps[@]} - 1; i >= 0; i--)); do
            lowerdirs="$lowerdirs:''${deps[$i]}/basePackage"
          done

          nix_overlayfs_registry_sources=()
          for i in "''${!deps[@]}"; do
            nix_overlayfs_registry_sources+=("''${deps[$i]}/basePackage")
          done
          nix_overlayfs_registry_sources+=("__STOREPATH__/basePackage")
          nix_overlayfs_registry_sources+=("$appdir")

          state_dir="$appdir/.nix-overlayfs"
          mkdir -p "$state_dir"

          nix_overlayfs_registry_signature="$state_dir/registry-sources"
          nix_overlayfs_registry_signature_next="$tempdir/registry-sources"
          for nix_overlayfs_registry_source in "''${nix_overlayfs_registry_sources[@]}"; do
            if [ "$nix_overlayfs_registry_source" = "$appdir" ]; then
              continue
            fi
            ${pkgs.coreutils}/bin/readlink -f "$nix_overlayfs_registry_source"
          done > "$nix_overlayfs_registry_signature_next"

          if [ -f "$appdir/system.reg" ] \
            && [ -f "$appdir/user.reg" ] \
            && [ -f "$appdir/userdef.reg" ] \
            && [ -f "$nix_overlayfs_registry_signature" ] \
            && cmp -s "$nix_overlayfs_registry_signature" "$nix_overlayfs_registry_signature_next"; then
            :
          else
            ${overlayfsLib.scripts.mergeWineRegistries}/bin/merge-wine-registries "$appdir" "''${nix_overlayfs_registry_sources[@]}"
            cp -f "$nix_overlayfs_registry_signature_next" "$nix_overlayfs_registry_signature"
          fi

          nix_overlayfs_prepare_upperdir_skeleton() {
            local lowerdir=""
            local lower_drive_c=""
            local source_dir=""
            local relative_dir=""
            local -a nix_overlayfs_lowerdirs=()

            IFS=: read -r -a nix_overlayfs_lowerdirs <<< "$lowerdirs"
            for lowerdir in "''${nix_overlayfs_lowerdirs[@]}"; do
              lower_drive_c="$lowerdir/drive_c"
              [ -d "$lower_drive_c" ] || continue

              while IFS= read -r -d "" source_dir; do
                relative_dir="''${source_dir#"$lowerdir"/}"
                [ "$relative_dir" != "$source_dir" ] || continue
                mkdir -p "$appdir/$relative_dir"
                chmod a+rwx "$appdir/$relative_dir" || true
              done < <(${pkgs.findutils}/bin/find "$lower_drive_c" -maxdepth 5 -type d -print0)
            done
          }

          nix_overlayfs_prepare_upperdir_skeleton

          rm -rf "$overlay_workdir"
          mkdir -p "$overlay_workdir"
          ${lib.optionalString hostIntegration ''
            rm -f \
              "$appdir/drive_c/windows/system32/start.exe" \
              "$appdir/drive_c/windows/syswow64/start.exe"
            mkdir -p \
              "$appdir/drive_c/windows/system32" \
              "$appdir/drive_c/windows/syswow64"
            cp -f '${overlayfsLib.hostStartShim}/bin/x86_64/start.exe' "$appdir/drive_c/windows/system32/start.exe"
            cp -f '${overlayfsLib.hostStartShim}/bin/i686/start.exe' "$appdir/drive_c/windows/syswow64/start.exe"
          ''}

          ${pkgs.fuse-overlayfs}/bin/fuse-overlayfs \
            -o "lowerdir=$lowerdirs,upperdir=$appdir,workdir=$overlay_workdir,squash_to_uid=$(${pkgs.coreutils}/bin/id --user),squash_to_gid=$(${pkgs.coreutils}/bin/id --group)" \
            "$tempdir/overlay"

          cd "$tempdir/overlay/"

          ${if session == null then "" else renderEnvExports session.env}

          nix_overlayfs_hide_ld_so_preload() {
            if [ "''${NIX_OVERLAYFS_DIRECT_MODE:-0}" = 1 ] \
              || [ "''${NIX_OVERLAYFS_PRESERVE_LD_SO_PRELOAD:-0}" = 1 ] \
              || [ ! -f /etc/ld.so.preload ]; then
              return 0
            fi

            : > "$tempdir/empty-ld.so.preload"
            if ! ${pkgs.util-linux}/bin/mount --bind "$tempdir/empty-ld.so.preload" /etc/ld.so.preload; then
              echo "warning: failed to hide /etc/ld.so.preload in Wine mount namespace" >&2
            fi
          }

          nix_overlayfs_hide_ld_so_preload
          ${if session == null then "" else session.preCommands}

          nix_overlayfs_registry_string() {
            local value="$1"
            value="''${value//\\/\\\\}"
            value="''${value//\"/\\\"}"
            printf '"%s"' "$value"
          }

          nix_overlayfs_upsert_user_reg_section() {
            local section="$1"
            local registry="$appdir/user.reg"
            local body_file="$tempdir/nix-overlayfs-user-reg-body.$$"
            local next_registry="$tempdir/nix-overlayfs-user-reg.$$"

            cat > "$body_file"
            mkdir -p "$(${pkgs.coreutils}/bin/dirname "$registry")"

            if [ -f "$registry" ]; then
              NIX_OVERLAYFS_USER_REG_SECTION="[$section]" ${pkgs.gawk}/bin/awk '
                BEGIN { section = ENVIRON["NIX_OVERLAYFS_USER_REG_SECTION"] }
                /^\[/ { skip = ($0 == section || substr($0, 1, length(section) + 1) == section " ") }
                !skip { print }
              ' "$registry" > "$next_registry"
            else
              printf '%s\n\n' 'WINE REGISTRY Version 2' > "$next_registry"
            fi

            {
              printf '\n[%s] %s\n' "$section" "$(${pkgs.coreutils}/bin/date +%s)"
              cat "$body_file"
            } >> "$next_registry"

            mv "$next_registry" "$registry"
            rm -f "$body_file"
          }

          nix_overlayfs_configure_host_browser() {
            ${
              if session == null || !hostIntegration then
                ''
                  :
                ''
              else
                ''
                                nix_overlayfs_upsert_user_reg_section 'Software\\Wine\\WineBrowser' <<EOF
                  "Browsers"=$(nix_overlayfs_registry_string '${lib.getExe overlayfsLib.hostUrlOpener}')
                  EOF
                ''
            }
          }

          nix_overlayfs_configure_host_browser_or_warn() {
            if ! nix_overlayfs_configure_host_browser; then
              echo "warning: failed to configure WineBrowser host URL opener for ${basePackageName}" >&2
            fi
          }

          nix_overlayfs_remove_start_shim() {
            ${
              if hostIntegration then
                ''
                  rm -f \
                    "$appdir/drive_c/windows/system32/start.exe" \
                    "$appdir/drive_c/windows/syswow64/start.exe"

                  if [ -f "$tempdir/overlay/drive_c/windows/system32/start.exe" ] \
                    && cmp -s "$tempdir/overlay/drive_c/windows/system32/start.exe" '${overlayfsLib.hostStartShim}/bin/x86_64/start.exe'; then
                    rm -f "$tempdir/overlay/drive_c/windows/system32/start.exe"
                  fi
                  if [ -f "$tempdir/overlay/drive_c/windows/syswow64/start.exe" ] \
                    && cmp -s "$tempdir/overlay/drive_c/windows/syswow64/start.exe" '${overlayfsLib.hostStartShim}/bin/i686/start.exe'; then
                    rm -f "$tempdir/overlay/drive_c/windows/syswow64/start.exe"
                  fi
                ''
              else
                ''
                  :
                ''
            }
          }

          nix_overlayfs_enable_start_shim() {
            ${
              if hostIntegration then
                ''
                  case ";''${WINEDLLOVERRIDES:-};" in
                    *";start.exe=n,b;"*)
                      ;;
                    *)
                      export WINEDLLOVERRIDES="start.exe=n,b''${WINEDLLOVERRIDES:+;$WINEDLLOVERRIDES}"
                      ;;
                  esac
                ''
              else
                ''
                  :
                ''
            }
          }

          nix_overlayfs_shutdown_wine_prefix() {
            ${
              if session != null && session ? commands && session.commands ? wineserver then
                ''
                  local overlay_root="$1"
                  local shutdown_timeout="''${NIX_OVERLAYFS_WINESERVER_SHUTDOWN_TIMEOUT:-30s}"
                  local kill_timeout="''${NIX_OVERLAYFS_WINESERVER_KILL_TIMEOUT:-5s}"
                  local wineserver=${lib.escapeShellArg session.commands.wineserver}

                  [ -d "$overlay_root" ] || return 0
                  [ -x "$wineserver" ] || return 0

                  if ! ${pkgs.coreutils}/bin/timeout --foreground "$shutdown_timeout" \
                    env WINEPREFIX="$overlay_root" WINEARCH="''${WINEARCH:-}" "$wineserver" --wait 2>/dev/null; then
                    echo "warning: wineserver --wait exceeded $shutdown_timeout for ${basePackageName}; killing remaining Wine processes" >&2
                    env WINEPREFIX="$overlay_root" WINEARCH="''${WINEARCH:-}" "$wineserver" -k 2>/dev/null || true
                    ${pkgs.coreutils}/bin/timeout --foreground "$kill_timeout" \
                      env WINEPREFIX="$overlay_root" WINEARCH="''${WINEARCH:-}" "$wineserver" --wait 2>/dev/null || true
                  fi
                ''
              else
                ":"
            }
          }

          ${urlSchemeRegistrationCommands}
          ${overlayProcessCommands}

          nix_overlayfs_post_launch_ran=0
          nix_overlayfs_run_post_launch_once() {
            if [ "$nix_overlayfs_post_launch_ran" = 0 ]; then
              nix_overlayfs_post_launch_ran=1
              ${extraPostLaunchCommands}
            fi
          }

          cleanup_runtime_session() {
            local status=$?
            trap - EXIT HUP INT TERM
            nix_overlayfs_run_post_launch_once || true
            ${if session == null then "" else session.postCommands}
            nix_overlayfs_remove_start_shim || true
            nix_overlayfs_shutdown_wine_prefix "$tempdir/overlay" || true
            exit $status
          }

          trap cleanup_runtime_session EXIT
          trap 'exit 129' HUP
          trap 'exit 130' INT
          trap 'exit 143' TERM

          nix_overlayfs_process_url_requests() {
            local callback_url=""
            local processing_file=""
            local request_file=""

            mkdir -p "$state_dir/open-requests"
            for request_file in "$state_dir"/open-requests/request.*; do
              [ -f "$request_file" ] || continue
              processing_file="$request_file.processing.$$"
              if ! mv "$request_file" "$processing_file" 2>/dev/null; then
                continue
              fi

              callback_url="$(cat "$processing_file" 2>/dev/null || true)"
              rm -f "$processing_file"
              [ -n "$callback_url" ] || continue

              if ! ( ${urlSchemeOpenInvocation} ); then
                echo "warning: failed to open URL in active ${basePackageName} Wine prefix: $callback_url" >&2
              fi
            done
          }

          nix_overlayfs_launch_application() {
            local executable="$1"
            local -a launch_wd_args=()
            local launch_working_directory="${
              if workingDirectory != null then "$tempdir/overlay/${workingDirectory}" else ""
            }"
            shift

            if [ -n "$launch_working_directory" ]; then
              launch_wd_args=(--wd "$launch_working_directory")
            fi

            if [ "''${NIX_OVERLAYFS_DIRECT_MODE:-0}" = 1 ]; then
              if [ -n "$launch_working_directory" ]; then
                (
                  cd "$launch_working_directory"
                  ${launchProgram} "$executable" "$@"
                ) &
              else
                ${launchProgram} "$executable" "$@" &
              fi
            else
              ${pkgs.util-linux}/bin/unshare \
                --map-user="$originalUser" \
                "''${launch_wd_args[@]}" \
                ${launchProgram} "$executable" "$@" &
            fi

            launch_pid=$!
          }

          nix_overlayfs_find_active_session() {
            active_pid=""
            active_overlay=""

            if [ -f "$state_dir/session.pid" ] && [ -f "$state_dir/overlay-root" ]; then
              active_pid="$(cat "$state_dir/session.pid" 2>/dev/null || true)"
              active_overlay="$(cat "$state_dir/overlay-root" 2>/dev/null || true)"
            fi

            if [ -n "$active_pid" ] \
              && [ -n "$active_overlay" ] \
              && [ -d "$active_overlay" ] \
              && nix_overlayfs_active_session_exists; then
              return 0
            fi

            return 1
          }

          nix_overlayfs_forward_url_to_active_session() {
            callback_url="$1"
            if nix_overlayfs_find_active_session; then
              nix_overlayfs_load_session_env
              ${activeUrlSchemeOpenInvocation}
              return $?
            fi

            return 1
          }

          nix_overlayfs_write_state_file() {
            local destination="$1"
            local value="$2"
            local tmp_file="$destination.$$"

            printf '%s\n' "$value" > "$tmp_file"
            mv "$tmp_file" "$destination"
          }

          nix_overlayfs_prepare_launch_session() {
            :
            ${lib.optionalString hostIntegration ''
              nix_overlayfs_configure_host_browser_or_warn
              nix_overlayfs_register_url_handlers
              ${urlSchemeRegistryCommands}
              nix_overlayfs_enable_start_shim
            ''}
            ${extraPreLaunchCommands}

            ${lib.optionalString hostIntegration ''
              nix_overlayfs_write_state_file "$state_dir/session.pid" "$$"
              nix_overlayfs_write_state_file "$state_dir/overlay-root" "$tempdir/overlay"
              nix_overlayfs_record_session_env
            ''}
          }

          nix_overlayfs_run_launch_loop() {
            nix_overlayfs_launch_application "$tempdir/overlay/${executablePath}" "$@"
            launch_running=1
            launch_status=0

            while [ "$launch_running" = 1 ] || nix_overlayfs_overlay_process_exists "$tempdir/overlay"; do
              ${lib.optionalString hostIntegration "nix_overlayfs_process_url_requests"}
              if [ "$launch_running" = 1 ] && ! kill -0 "$launch_pid" 2>/dev/null; then
                wait "$launch_pid" || launch_status=$?
                launch_running=0
              fi
              sleep 1
            done

            if [ "$launch_running" = 1 ]; then
              wait "$launch_pid" || launch_status=$?
            fi

            nix_overlayfs_run_post_launch_once
            return "$launch_status"
          }

          ${lib.optionalString hostIntegration ''
            if [ "''${1:-}" = "--nix-overlayfs-open-url" ]; then
              callback_url="''${2:-}"
              if [ -z "$callback_url" ]; then
                echo "Missing URL for --nix-overlayfs-open-url" >&2
                exit 2
              fi

              if nix_overlayfs_forward_url_to_active_session "$callback_url"; then
                exit 0
              fi

              nix_overlayfs_prepare_launch_session
              nix_overlayfs_run_launch_loop "$callback_url"
              exit "$?"
            fi
          ''}

          nix_overlayfs_prepare_launch_session
          nix_overlayfs_run_launch_loop "$@"
          exit "$?"
        '';
    in
    ''
      mkdir bin libexec
      ln --symbolic ${basePackage} basePackage

      # If package is executable, copy scripts, replace placeholder values with store path and name them appropriately
      if [[ "" != "${executableName}" ]]; then
        cp ${entryScript} ./bin/${executableName}-unwrapped
        sed -i "s#__STOREPATH__#$out#g" ./bin/${executableName}-unwrapped

        cp ${entryScriptWrapper} ./bin/${executableName}
        sed -i "s#__STOREPATH__#$out#g" ./bin/${executableName}

        cp ${
          (envScript { inherit executablePath overlayDependencies extraPreLaunchCommands; })
        } ./libexec/${executableName}-setupEnv.sh
        sed -i "s#__STOREPATH__#$out#g" ./libexec/${executableName}-setupEnv.sh
        chmod a+x ./libexec/${executableName}-setupEnv.sh ./bin/${executableName} ./libexec/${executableName}-setupEnv.sh
      fi
    '';

  installPhase = ''
    mkdir $out
    mv bin basePackage libexec $out/
  '';

  passthru = passthru // {
    inherit
      basePackage
      executablePath
      hostIntegration
      overlayDependencies
      launchProgram
      namespaceMode
      processTerminationTimeout
      stateMode
      ;
  };
}
