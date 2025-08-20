# Author: Libor Štěpánek 2025
{
  lib,
  pkgs,
  mkOverlayfsPackage,
  diffs,

  writeShellScript,
  stdenv,

  xorg,
  util-linux,
  mount,
  bash,
  jq,
  jd-diff-patch,
  gnused,
  moreutils,
  x11vnc,

  wine-base-env,
  autohotkey,
  nix-overlayfs,
}:
{
  wine,
  pname,
  version,
  src,
  packageName,
  executableName ? "",
  executablePath ? "",
  extraPreLaunchCommands ? "",
  overlayDependencies ? [ ],
  extraPathsToRemove ? [ ],
  extraPathsToInclude ? [ ],
  silentFlags ? "",
  ahkScript ? "",
  postInstall ? "",
  launchVncServer ? false,
  unshareInstall ? null,
  ...
}:
let
  scripts = nix-overlayfs.lib.scripts;
  winedbg = "-all";
  pathsToRemove = builtins.concatStringsSep " " (
    builtins.map (val: "\"" + val + "\"") extraPathsToRemove
  );

  ahkScriptPresent = ahkScript != "";

  baseEnv = [
    (wine-base-env.override { inherit wine; })
  ];
  overlayDependenciesPlusUtils =
    (lib.optionals ahkScriptPresent [
      autohotkey
    ])
    ++ overlayDependencies;
  overlayDependenciesPlusEnv =
    baseEnv ++ (builtins.map (pkg: pkg.override { inherit wine; }) overlayDependenciesPlusUtils);

  # Select the installer files based on the architecture
  deps = builtins.map (x: "\"" + x + "\"") overlayDependenciesPlusEnv;

  # Create the base package for mkOverlayfsPackage
  basePackage =
    let
      defaultUnshareInstallSteps = (
        [
          ''
            ${lib.getExe wine} '${src}' ${silentFlags} ${if ahkScriptPresent then "&" else ""}
          ''
        ]
        ++ (lib.optionals ahkScriptPresent [
          ''
            cat > unattended-install.ahk <<'EOF'
            ${ahkScript}
            EOF

            ${lib.getExe wine} "$WINEPREFIX${autohotkey.executablePath}" "Z:$(pwd)/unattended-install.ahk"
          ''
        ])
        ++ (lib.optionals (postInstall != "") [ postInstall ])
        ++ [
          ''
            wineserver --wait
          ''
        ]
      );

      # Last layer of installation, run installation and wait for WINE server to terminate
      buildPhaseUnshareScript = writeShellScript "buildUnshare" (
        (lib.concatStringsSep "\n" (
          (lib.optionals launchVncServer [
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
              wineExe = lib.getExe wine;
            })
          ])
          ++ (lib.optionals launchVncServer [
            ''
              kill $X11VNC_PID
            ''
          ])
        ))
      );

      # Second build script, run inside mount namespace
      buildPhaseEnvScript = writeShellScript "buildEnv" ''
        # Create overlay to capture changed files
        mount -t overlay -o lowerdir=./wineprefix,upperdir=./data,workdir=./work overlay ./merged

        export USER="$originalUser"

        # Create virtual framebuffer for WINE
        Xvfb :999 -screen 0 1600x900x16 &
        XVFB_PROC_ID=$!
        export DISPLAY=:999

        # run install script
        unshare --map-user="$originalUser" "${buildPhaseUnshareScript}"

        # terminate framebuffer
        kill $XVFB_PROC_ID;
      '';
    in
    stdenv.mkDerivation rec {
      inherit pname version src;

      # Disable default unpack phase
      unpackPhase = ''true'';

      buildInputs = [
        wine
        xorg.xorgserver
        util-linux
        mount
        bash
        jq
        jd-diff-patch
        scripts.json2reg
        scripts.reg2json
        gnused
        moreutils
      ];

      buildPhase =
        let
          jqRegMerge = ".[0] * .[1]";
          jqRemoveNulls = "del(.. | select(. == null))";
          dupesToRemove = lib.subtractLists extraPathsToInclude diffs.dupes;
        in
        ''
          mkdir wineprefix data work merged

          deps=(${lib.strings.concatStringsSep " " deps});

          # copy registry JSONs from base env
          cp "''${deps[0]}/basePackage/system.json" "''${deps[0]}/basePackage/user.json" "''${deps[0]}/basePackage/userdef.json" ./

          # copy dependencies to working directory, merge all registry JSONs, mark files as writable
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

          # convert merged JSONs to registry files
          json2reg system.json system.reg
          json2reg user.json user.reg
          json2reg userdef.json userdef.reg

          # copy converted files to prefix directory
          cp system.reg user.reg userdef.reg ./wineprefix/

          export WINEPREFIX=$PWD/merged
          export temp=$(mktemp -d)
          export HOME="$temp"
          export originalUser=$(id --user --name)

          # run
          unshare --fork --map-root-user --mount bash -c -- '${buildPhaseEnvScript}'

          rm --force ./data/.update-timestamp
          mkdir --parents ./data/bin

          chmod --recursive a+rw ./
          rm --recursive --force "./data/drive_c/ProgramData/Microsoft/Windows/Start Menu/Programs/"
          find ./data/ -type d -empty -delete

          # convert each registry file to JSON, apply supplied patch, generate diff, and convert back to .reg
          if [ -e ./data/system.reg ]; then
            # Remove entries with non-deterministic values
            sed -i '/^"InstallDate"=/d' ./data/system.reg
            sed -i '/^"FirstInstallDateTime"=/d' ./data/system.reg
            reg2json ./data/system.reg > system.new.json
            jq '${jqRemoveNulls}' system.new.json | sponge system.new.json
            jd -p -f=merge -o system.new.json "${diffs.system}" system.new.json || true
            jd -f=merge -o ./data/system.json system.json system.new.json || true
            json2reg system.new.json ./data/system.reg
          fi

          if [ -e ./data/user.reg ]; then
            # Remove entries with non-deterministic values
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

          # remove duplicate and non-deterministic files, clean up empty directories
          rm --force ${lib.concatMapStringsSep " " (x: "'${x}'") dupesToRemove}
          rm --recursive --force ./windows/Installer ./users/nixbld/Desktop ./users/Public/Desktop
          rm --force ${pathsToRemove}
          find . -type d -empty -delete
          popd || exit 1
        '';

      installPhase = ''
        mkdir $out
        mv ./data/* $out
      '';

      passthru = {
        inherit buildPhaseUnshareScript buildPhaseEnvScript;
      };
    };
in
# generate overlay package from the base package
mkOverlayfsPackage {
  inherit
    basePackage
    executableName
    executablePath
    extraPreLaunchCommands
    ;
  overlayDependencies = overlayDependenciesPlusEnv;
  interpreter = lib.getExe wine;
  basePackageName = packageName;
  extraEnvCommands = ''
    export WINEPREFIX="$tempdir/overlay"
    export WINEDEBUG="${winedbg}"
  '';
}
