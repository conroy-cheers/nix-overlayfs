# Author: Libor Štěpánek 2025
{
  lib,
  mkOverlayfsPackage,
  pkgs,
  diffs,
  self,
}: {
  packageName,
  executableName ? "",
  executablePath ? "",
  version ? "latest",
  overlayDependencies ? [],
  extraPathsToRemove ? [],
  silentFlags ? null,
  ...
}: let
  wine-base-env = self.outputs.packages.x86_64-linux.wine-base-env;
  scripts = self.outputs.lib.scripts;
  winedbg = "-all";
  pathsToRemove = builtins.concatStringsSep " " (builtins.map (val: "\"" + val + "\"") extraPathsToRemove);

  # Get path from package name, select the correct manifest file, convert it to JSON and import it as an attribute set
  manifest = let
    manifest-json = (
      pkgs.runCommand "winpkgsPath" {nativeBuildInputs = [pkgs.yj];} ''
        ${scripts.getWinpkgsPath} '${packageName}' '${version}' > $out
      ''
    );
  in
    builtins.fromJSON (builtins.readFile "${manifest-json}");

  overlayDependenciesPlusEnv = [wine-base-env] ++ overlayDependencies;

  # Select the installer files based on the architecture
  installer = builtins.head ((builtins.filter (x: x.Architecture == "x64") manifest.Installers) ++ (builtins.filter (x: x.Architecture == "x86") manifest.Installers) ++ (builtins.filter (x: x.Architecture == "neutral") manifest.Installers));
  deps = builtins.map (x: "\"" + x + "\"") overlayDependenciesPlusEnv;

  # Group installer types for silent flag selection
  installerType = installer.InstallerType or manifest.InstallerType or "exe";

  # Create the base package for mkOverlayfsPackage
  basePackage = pkgs.stdenv.mkDerivation rec {
    # Extract metadata from manifest
    pname = manifest.PackageIdentifier;
    version = manifest.PackageVersion;

    # Download selected installer
    src = pkgs.fetchurl {
      url = installer.InstallerUrl;
      sha256 = "${installer.InstallerSha256}";
    };

    # Disable default unpack phase
    unpackPhase = ''true'';

    buildInputs = with pkgs; [
      self.inputs.nix-gaming.packages.x86_64-linux.wine-tkg
      xorg.xorgserver
      util-linux
      mount
      bash
      jq
      jd-diff-patch
      scripts.json2reg
      scripts.reg2json
      gnused
    ];

    buildPhase = let
      # Predefined set of silent flags
      silentFlagsIndex = {
        nullsoft = "/S";
        inno = "/VERYSILENT";
        exe = manifest.InstallerSwitches.Silent;
      };

      # Use supplied silent flags or default to predefined ones
      silentFlag = if silentFlags != null then silentFlags else silentFlagsIndex.${installerType};

      # Last layer of installation, run installation and wait for WINE server to terminate
      buildPhaseUnshareScript = pkgs.writeShellScript "buildUnshare" ''
        ${lib.getExe self.inputs.nix-gaming.packages.x86_64-linux.wine-tkg} '${src}' ${silentFlag}

        wineserver --wait
      '';

      # Second build script, run inside mount namespace
      buildPhaseEnvScript = pkgs.writeShellScript "buildEnv" ''
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
    in ''
      mkdir wineprefix data work merged

      deps=(${pkgs.lib.strings.concatStringsSep " " deps});

      # copy registry JSONs from base env
      cp "''${deps[0]}/basePackage/system.json" "''${deps[0]}/basePackage/user.json" "''${deps[0]}/basePackage/userdef.json" ./

      # copy dependencies to working directory, merge all registry JSONs, mark files as writable
      for i in ''${!deps[@]}; do
        if [[ $i != 0 ]]; then
          jd -f=merge -p -o system.json "''${deps[$i]}/basePackage/system.json" system.json || true
          jd -f=merge -p -o user.json "''${deps[$i]}/basePackage/user.json" user.json || true
          jd -f=merge -p -o userdef.json "''${deps[$i]}/basePackage/userdef.json" userdef.json || true
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

      # Remove entries with non-deterministic values
      sed -i '/^"InstallDate"=/d' ./data/system.reg
      sed -i '/^"FirstInstallDateTime"=/d' ./data/system.reg
      sed -i -E '/tmp.[0-9A-Za-z]{10}/d' ./data/user.reg

      # convert each registry file to JSON, apply supplied patch, generate diff, and convert back to .reg
      reg2json ./data/system.reg > system.new.json
      jd -p -f=merge -o system.new.json "${diffs.system}" system.new.json || true
      jd -f=merge -o ./data/system.json system.json system.new.json || true
      json2reg system.new.json ./data/system.reg

      reg2json ./data/user.reg > user.new.json
      jd -p -f=merge -o system.new.json "${diffs.user}" system.new.json || true
      jd -f=merge -o ./data/user.json user.json user.new.json || true
      json2reg user.new.json ./data/user.reg

      reg2json ./data/userdef.reg > userdef.new.json
      jd -f=merge -o ./data/userdef.json userdef.json userdef.new.json || true
      json2reg userdef.new.json ./data/userdef.reg

      pushd ./data/drive_c || exit 1

      # remove duplicate and non-deterministic files, clean up empty directories
      rm --force ${diffs.dupes}
      rm --recursive --force ./windows/Installer ./users/nixbld/Desktop ./users/Public/Desktop
      rm --force ${pathsToRemove}
      find . -type d -empty -delete
      popd || exit 1
    '';

    installPhase = ''
      mkdir $out
      mv ./data/* $out
    '';
  };
in
  # generate overlay package from the base package
  mkOverlayfsPackage {
    inherit basePackage executableName executablePath;
    overlayDependencies = overlayDependenciesPlusEnv;
    interpreter = lib.getExe self.inputs.nix-gaming.packages.x86_64-linux.wine-tkg;
    basePackageName = packageName;
    extraEnvCommands = ''
      export WINEPREFIX="$tempdir/overlay"
      export WINEDEBUG="${winedbg}"
    '';
  }
