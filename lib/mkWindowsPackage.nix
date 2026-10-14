# Maintainer: Conroy Cheers <conroy@corncheese.org>
# Based on original work by Libor Stepanek 2025
{
  lib,
  mkOverlayfsPackage,
  diffs,

  writeShellScript,
  stdenv,

  xorg-server,
  util-linux,
  mount,
  bash,
  jq,
  jd-diff-patch,
  gnused,
  moreutils,
  x11vnc,
  coreutils,
  rsync,

  overlayfsLib,
}:
{
  runtime,
  pname,
  version,
  src,
  packageName,
  executableName ? "",
  executablePath ? "",
  workingDirectory ? null,
  extraPreLaunchCommands ? "",
  extraPostLaunchCommands ? "",
  overlayDependencies ? [ ],
  extraPathsToRemove ? [ ],
  extraPathsToInclude ? [ ],
  silentFlags ? "",
  ahkScript ? "",
  postInstall ? "",
  launchVncServer ? false,
  unshareInstall ? null,
  buildNamespaceMode ? "auto",
  hostIntegration ? true,
  managedRuntime ? "auto",
  namespaceMode ? "auto",
  processTerminationTimeout ? 5,
  stateMode ? "persistent",
  wineserverWaitTimeout ? null,
  runtimeEnvVars ? { },
  urlSchemes ? [ ],
  urlSchemeDiscoveryCommands ? "",
  urlSchemeOpenCommands ? "",
  entrypointWrapper ? (entrypoint: ''exec ${entrypoint} "$@"''),
  ...
}:
let
  scripts = overlayfsLib.scripts;
  _checkBuildNamespaceMode =
    if
      builtins.elem buildNamespaceMode [
        "auto"
        "required"
        "direct"
      ]
    then
      true
    else
      throw "buildNamespaceMode must be one of: auto, required, direct";
  _checkManagedRuntime =
    if
      builtins.elem managedRuntime [
        "auto"
        "disabled"
      ]
    then
      true
    else
      throw "managedRuntime must be one of: auto, disabled";
  winedbg = "-all";
  packageVersion = version;
  pathsToRemove = builtins.concatStringsSep " " (
    builtins.map (val: "\"" + val + "\"") extraPathsToRemove
  );
  renderEnvExports =
    env: builtins.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "export ${n}=${v}") env);
  managedRuntimeCommands = lib.optionalString (managedRuntime == "disabled") ''
    export WINEDLLOVERRIDES="mscoree,mshtml=d''${WINEDLLOVERRIDES:+;$WINEDLLOVERRIDES}"
  '';

  ahkScriptPresent = ahkScript != "";

  baseEnvLayer =
    if runtime ? selectBaseEnvLayer then
      runtime.selectBaseEnvLayer { inherit hostIntegration managedRuntime; }
    else if hostIntegration && managedRuntime == "auto" then
      runtime.baseEnvLayer
    else
      throw "the selected runtime does not provide capability-specific base environment layers";
  baseEnv = [ baseEnvLayer ];
  overlayDependenciesPlusUtils =
    (lib.optionals ahkScriptPresent [
      runtime.autohotkeyLayer
    ])
    ++ overlayDependencies;
  overlayDependenciesPlusEnv = baseEnv ++ overlayDependenciesPlusUtils;
  launchSession = runtime.mkSession {
    phase = "launch";
    sessionRoot = "$tempdir/runtime-session";
    overlayRoot = "$tempdir/overlay";
    homeDir = "$HOME";
  };
  hostBrowserBootstrapCommands = lib.optionalString hostIntegration ''
        nix_overlayfs_upsert_user_reg_section 'Software\\Wine\\WineBrowser' <<EOF
    "Browsers"=$(nix_overlayfs_registry_string '${lib.getExe overlayfsLib.hostUrlOpener}')
    EOF
  '';
  protocolRegistrationCommands = lib.optionalString hostIntegration ''
        if [ -s "$nix_overlayfs_url_schemes_file" ]; then
          nix_overlayfs_protocol_executable=${lib.escapeShellArg executablePath}
          case "$nix_overlayfs_protocol_executable" in
            /drive_c/*)
              nix_overlayfs_protocol_executable="C:\\''${nix_overlayfs_protocol_executable#/drive_c/}"
              nix_overlayfs_protocol_executable="''${nix_overlayfs_protocol_executable//\//\\}"
              ;;
            drive_c/*)
              nix_overlayfs_protocol_executable="C:\\''${nix_overlayfs_protocol_executable#drive_c/}"
              nix_overlayfs_protocol_executable="''${nix_overlayfs_protocol_executable//\//\\}"
              ;;
            *)
              nix_overlayfs_protocol_executable="$(${runtime.toolsPackage}/bin/winepath -w "$tempdir/overlay/${executablePath}")"
              ;;
          esac
          while IFS= read -r nix_overlayfs_url_scheme; do
            nix_overlayfs_upsert_user_reg_section 'Software\\Classes\\'"$nix_overlayfs_url_scheme" <<EOF
    @=$(nix_overlayfs_registry_string "URL:$nix_overlayfs_url_scheme Protocol")
    "URL Protocol"=""
    EOF
            nix_overlayfs_upsert_user_reg_section 'Software\\Classes\\'"$nix_overlayfs_url_scheme"'\\shell\\open\\command' <<EOF
    @=$(nix_overlayfs_registry_string "\"$nix_overlayfs_protocol_executable\" \"%1\"")
    EOF
          done < "$nix_overlayfs_url_schemes_file"
        fi
  '';

  deps = builtins.map (x: "\"" + x + "\"") overlayDependenciesPlusEnv;

  buildSession = runtime.mkSession {
    phase = "build";
    sessionRoot = "$PWD/runtime-session";
    overlayRoot = "$PWD/merged";
    homeDir = "$temp";
  };

  basePackage =
    let
      waitForWineserver =
        if wineserverWaitTimeout == null then
          ''
            ${buildSession.commands.wineserver} --wait
          ''
        else
          ''
            timeout ${toString wineserverWaitTimeout} ${buildSession.commands.wineserver} --wait || {
              echo "warning: wineserver did not exit within ${toString wineserverWaitTimeout}s; killing remaining Wine processes" >&2
              ${buildSession.commands.wineserver} -k || true
            }
          '';
      defaultUnshareInstallSteps = (
        [
          ''
            ${buildSession.commands.wine} '${src}' ${silentFlags} ${if ahkScriptPresent then "&" else ""}
          ''
        ]
        ++ (lib.optionals ahkScriptPresent [
          ''
            cat > unattended-install.ahk <<'EOF'
            ${ahkScript}
            EOF

            ${buildSession.commands.wine} "$WINEPREFIX${runtime.autohotkeyLayer.executablePath}" "Z:$(pwd)/unattended-install.ahk"
          ''
        ])
        ++ (lib.optionals (postInstall != "") [ postInstall ])
        ++ [
          waitForWineserver
        ]
      );

      buildPhaseUnshareScript = writeShellScript "buildUnshare" (
        (lib.concatStringsSep "\n" (
          [
            ''
              cleanup_runtime_session() {
                local status=$?
                ${buildSession.postCommands}
                exit $status
              }

              trap cleanup_runtime_session EXIT

              ${renderEnvExports buildSession.env}
              ${managedRuntimeCommands}
              ${buildSession.preCommands}
            ''
          ]
          ++ (lib.optionals launchVncServer [
            ''
              sleep 5
              ${lib.getExe x11vnc} \
                -viewonly \
                -display "$DISPLAY" \
                -shared -noxdamage -wait 5 &
              X11VNC_PID=$!
              sleep 5
            ''
          ])
          ++ (lib.optionals (unshareInstall == null) defaultUnshareInstallSteps)
          ++ (lib.optionals (unshareInstall != null) [
            (unshareInstall {
              inherit runtime;
              session = buildSession;
            })
          ])
          ++ (lib.optionals launchVncServer [
            ''
              kill $X11VNC_PID
            ''
          ])
        ))
      );

      buildPhaseEnvScript = writeShellScript "buildEnv" ''
        mount -t overlay -o lowerdir=./wineprefix,upperdir=./data,workdir=./work overlay ./merged

        export USER="$originalUser"

        Xvfb :999 -screen 0 1600x900x16 &
        XVFB_PROC_ID=$!
        export DISPLAY=:999

        unshare --map-user="$originalUser" "${buildPhaseUnshareScript}"
        INSTALL_STATUS=$?

        kill $XVFB_PROC_ID;

        exit $INSTALL_STATUS
      '';

      buildPhaseDirectScript = writeShellScript "buildDirect" ''
        xvfb_pid=""

        cleanup_direct_build() {
          status=$?
          trap - EXIT
          if [ -n "$xvfb_pid" ]; then
            kill "$xvfb_pid" 2>/dev/null || true
          fi
          exit "$status"
        }
        trap cleanup_direct_build EXIT

        cp -a "$PWD/wineprefix/." "$PWD/merged/"

        export USER="$originalUser"
        Xvfb :999 -screen 0 1600x900x16 &
        xvfb_pid=$!
        export DISPLAY=:999

        "${buildPhaseUnshareScript}"
        install_status=$?
        if [ "$install_status" -ne 0 ]; then
          exit "$install_status"
        fi

        rsync -a --checksum --compare-dest="$PWD/wineprefix/" "$PWD/merged/" "$PWD/data/"
      '';
    in
    stdenv.mkDerivation {
      inherit pname src;
      version = packageVersion;

      unpackPhase = "true";

      buildInputs = [
        xorg-server
        util-linux
        mount
        bash
        jq
        jd-diff-patch
        scripts.json2reg
        scripts.reg2json
        gnused
        moreutils
        rsync
      ]
      ++ buildSession.buildInputs;

      buildPhase =
        let
          jqRegMerge = ".[0] * .[1]";
          jqRemoveNulls = "del(.. | select(. == null))";
          dupesToRemove = lib.subtractLists extraPathsToInclude diffs.dupes;
        in
        ''
          mkdir wineprefix data work merged

          deps=(${lib.strings.concatStringsSep " " deps});

          cp "''${deps[0]}/basePackage/system.json" "''${deps[0]}/basePackage/user.json" "''${deps[0]}/basePackage/userdef.json" ./

          for i in ''${!deps[@]}; do
            if [[ $i != 0 ]]; then
              for file in system.json user.json userdef.json; do
                basepath="''${deps[$i]}/basePackage/$file"
                if [ -e "$basepath" ]; then
                  jq -s '${jqRegMerge}' $file "$basepath" | sponge $file || true
                fi
              done
            fi
            # Copy the directory itself so Wine control files such as
            # .update-timestamp survive composition. A trailing glob silently
            # drops dotfiles and makes Wine rerun Wow64Install on every layer.
            cp --recursive "''${deps[$i]}"/basePackage/. ./wineprefix/
            chmod --recursive +rw ./wineprefix
          done

          json2reg system.json system.reg
          json2reg user.json user.reg
          json2reg userdef.json userdef.reg

          cp system.reg user.reg userdef.reg ./wineprefix/

          export temp=$(mktemp -d)
          export originalUser=$(id --user --name)

          namespace_mode=${lib.escapeShellArg buildNamespaceMode}
          if [ "$namespace_mode" = auto ]; then
            if unshare --map-root-user --mount true 2>/dev/null; then
              namespace_mode=required
            else
              echo "warning: nix-overlayfs: build user/mount namespaces are unavailable; using materialized build mode" >&2
              namespace_mode=direct
            fi
          fi

          if [ "$namespace_mode" = direct ]; then
            "${buildPhaseDirectScript}"
          else
            unshare --fork --map-root-user --mount bash -c -- '${buildPhaseEnvScript}'
          fi

          rm --force ./data/.update-timestamp
          mkdir --parents ./data/bin

          # Kernel overlayfs owns private entries below work/work. Only the
          # produced delta needs permission normalization before packaging.
          chmod --recursive a+rw ./data
          rm --recursive --force "./data/drive_c/ProgramData/Microsoft/Windows/Start Menu/Programs/"
          find ./data/ -type d -empty -delete

          if [ -e ./data/system.reg ]; then
            sed -i '/^"InstallDate"=/d' ./data/system.reg
            sed -i '/^"FirstInstallDateTime"=/d' ./data/system.reg
            reg2json ./data/system.reg > system.new.json
            jq '${jqRemoveNulls}' system.new.json | sponge system.new.json
            jd -p -f=merge -o system.new.json "${diffs.system}" system.new.json || true
            jd -f=merge -o ./data/system.json system.json system.new.json || true
            json2reg system.new.json ./data/system.reg
          fi

          if [ -e ./data/user.reg ]; then
            sed -i -E '/tmp.[0-9A-Za-z]{10}/d' ./data/user.reg
            reg2json ./data/user.reg > user.new.json
            jq '${jqRemoveNulls}' user.new.json | sponge user.new.json
            jd -p -f=merge -o user.new.json "${diffs.user}" user.new.json || true
            jd -f=merge -o ./data/user.json user.json user.new.json || true
            json2reg user.new.json ./data/user.reg
          fi

          if [ -e ./data/userdef.reg ]; then
            reg2json ./data/userdef.reg > userdef.new.json
            jq '${jqRemoveNulls}' userdef.new.json | sponge userdef.new.json
            jd -f=merge -o ./data/userdef.json userdef.json userdef.new.json || true
            json2reg userdef.new.json ./data/userdef.reg
          fi

          # A successful no-op installer can legitimately produce no drive_c
          # delta once Wine's update marker is retained by the base layer.
          if [ -d ./data/drive_c ]; then
            pushd ./data/drive_c || exit 1

            rm --force ${lib.concatMapStringsSep " " (x: "'${x}'") dupesToRemove}
            rm --recursive --force \
              ./windows/Installer \
              ./users/nixbld/Desktop \
              ./users/nixbld/AppData/Roaming/Microsoft/Windows/Templates \
              ./users/nixbld/Documents \
              ./users/nixbld/Music \
              ./users/nixbld/Videos \
              ./users/nixbld/Desktop \
              ./users/nixbld/Pictures \
              ./users/nixbld/Downloads
            rm --force ${pathsToRemove}
            find . -type d -empty -delete
            popd || exit 1
          fi
        '';

      installPhase = ''
        mkdir $out
        # A layer is the complete set of entries below its root, including
        # dotfiles created by an installer.
        find ./data -mindepth 1 -maxdepth 1 -exec mv --target-directory="$out" -- {} +
      '';

      passthru = {
        inherit
          buildPhaseUnshareScript
          buildPhaseEnvScript
          buildPhaseDirectScript
          runtime
          ;
      };
    };
in
assert _checkBuildNamespaceMode;
assert _checkManagedRuntime;
mkOverlayfsPackage {
  inherit
    basePackage
    executableName
    executablePath
    hostIntegration
    namespaceMode
    processTerminationTimeout
    stateMode
    workingDirectory
    entrypointWrapper
    urlSchemes
    urlSchemeDiscoveryCommands
    urlSchemeOpenCommands
    ;
  extraPreLaunchCommands = hostBrowserBootstrapCommands + extraPreLaunchCommands;
  inherit extraPostLaunchCommands;
  urlSchemeRegistryCommands = protocolRegistrationCommands;
  overlayDependencies = overlayDependenciesPlusEnv;
  session = launchSession;
  launchProgram = launchSession.commands.wine;
  basePackageName = packageName;
  extraEnvCommands = ''
    export WINEDEBUG="${winedbg}"
  ''
  + builtins.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "export ${n}='${v}'") runtimeEnvVars)
  + lib.optionalString (managedRuntime == "disabled") ''

    export WINEDLLOVERRIDES="mscoree,mshtml=d''${WINEDLLOVERRIDES:+;$WINEDLLOVERRIDES}"
  '';
  passthru = {
    inherit managedRuntime runtime runtimeEnvVars;
  };
}
