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
  overlayDependencies ? [ ],
  extraPathsToRemove ? [ ],
  extraPathsToInclude ? [ ],
  silentFlags ? "",
  ahkScript ? "",
  postInstall ? "",
  launchVncServer ? false,
  unshareInstall ? null,
  runtimeEnvVars ? { },
  entrypointWrapper ? (entrypoint: ''exec ${entrypoint} "$@"''),
  ...
}:
let
  scripts = overlayfsLib.scripts;
  winedbg = "-all";
  pathsToRemove = builtins.concatStringsSep " " (
    builtins.map (val: "\"" + val + "\"") extraPathsToRemove
  );
  renderEnvExports =
    env: builtins.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "export ${n}=${v}") env);

  ahkScriptPresent = ahkScript != "";

  baseEnv = [ runtime.baseEnvLayer ];
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

  deps = builtins.map (x: "\"" + x + "\"") overlayDependenciesPlusEnv;

  buildSession = runtime.mkSession {
    phase = "build";
    sessionRoot = "$PWD/runtime-session";
    overlayRoot = "$PWD/merged";
    homeDir = "$temp";
  };

  basePackage =
    let
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
          ''
            ${buildSession.commands.wineserver} --wait
          ''
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
    in
    stdenv.mkDerivation rec {
      inherit pname version src;

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
            cp --recursive "''${deps[$i]}"/basePackage/* ./wineprefix/
            chmod --recursive +rw ./wineprefix
          done

          json2reg system.json system.reg
          json2reg user.json user.reg
          json2reg userdef.json userdef.reg

          cp system.reg user.reg userdef.reg ./wineprefix/

          export temp=$(mktemp -d)
          export originalUser=$(id --user --name)

          unshare --fork --map-root-user --mount bash -c -- '${buildPhaseEnvScript}'

          rm --force ./data/.update-timestamp
          mkdir --parents ./data/bin

          chmod --recursive a+rw ./
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
        '';

      installPhase = ''
        mkdir $out
        mv ./data/* $out
      '';

      passthru = {
        inherit buildPhaseUnshareScript buildPhaseEnvScript runtime;
      };
    };
in
mkOverlayfsPackage {
  inherit
    basePackage
    executableName
    executablePath
    workingDirectory
    extraPreLaunchCommands
    entrypointWrapper
    ;
  overlayDependencies = overlayDependenciesPlusEnv;
  session = launchSession;
  launchProgram = launchSession.commands.wine;
  basePackageName = packageName;
  extraEnvCommands = ''
    export WINEDEBUG="${winedbg}"
  ''
  + builtins.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "export ${n}='${v}'") runtimeEnvVars);
  passthru = {
    inherit runtime runtimeEnvVars;
  };
}
