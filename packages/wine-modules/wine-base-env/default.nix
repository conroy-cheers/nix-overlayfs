# Maintainer: Conroy Cheers <conroy@corncheese.org>
# Based on original work by Libor Štěpánek 2025
# the base environment included with all mkWinpkgsPackage packages
{
  lib,
  stdenv,
  fetchurl,
  util-linux,
  msitools,
  coreutils,

  runtime,
  xorg-server,
  jd-diff-patch,

  overlayfsLib,
}:
let
  session = runtime.mkSession {
    phase = "build";
    sessionRoot = "$PWD/runtime-session";
    overlayRoot = "$PWD/prefix";
    homeDir = "$HOME";
  };
  prefixInitCommands =
    if runtime ? mkPrefixInitCommands then runtime.mkPrefixInitCommands session else "";
  wineMonoDownloads = {
    "11.1.0" = {
      url = "https://github.com/wine-mono/wine-mono/releases/download/wine-mono-11.1.0/wine-mono-11.1.0-x86.msi";
      hash = "sha256-3rA0FDH4Jgsgn/9rx53cxUFLl/jpI2q5+9ykzlngqbk=";
    };
    "11.0.0" = {
      url = "https://github.com/wine-mono/wine-mono/releases/download/wine-mono-11.0.0/wine-mono-11.0.0-x86.msi";
      hash = "sha256-1+/t4Lm9z1ITT4zWztWdn+zpdvcLEaQAvbR7hkVpzSc=";
    };
    "10.3.0" = {
      url = "https://github.com/wine-mono/wine-mono/releases/download/wine-mono-10.3.0/wine-mono-10.3.0-x86.msi";
      hash = "sha256-zs5cYxgAlN/98B0PvjYqS2BuUoC5jN/RuFaM35tXL5g=";
    };
    "10.2.0" = {
      url = "https://github.com/wine-mono/wine-mono/releases/download/wine-mono-10.2.0/wine-mono-10.2.0-x86.msi";
      hash = "sha256-Th7T8C6S0FMTPQPd++/PbbSk3CMamu0zZ7FxF6iIR9g=";
    };
    "10.1.0" = {
      url = "https://github.com/wine-mono/wine-mono/releases/download/wine-mono-10.1.0/wine-mono-10.1.0-x86.msi";
      hash = "sha256-yIwkMYkLwyys7I1+pw5Tpa5LlcjFXKbnXvjbDkzPEHA=";
    };
    "10.0.0" = {
      url = "https://github.com/wine-mono/wine-mono/releases/download/wine-mono-10.0.0/wine-mono-10.0.0-x86.msi";
      hash = "";
    };
    "9.4.0" = {
      url = "https://github.com/wine-mono/wine-mono/releases/download/wine-mono-9.4.0/wine-mono-9.4.0-x86.msi";
      hash = "sha256-z2FzrpS3np3hPZp0zbJWCohvw9Jx+Uiayxz9vZYcrLI=";
    };
    "9.1.0" = {
      url = "https://github.com/wine-mono/wine-mono/releases/download/wine-mono-9.1.0/wine-mono-9.1.0-x86.msi";
      hash = "sha256-igoeaDe0lN9Jkn5ddZscaQjom4ovjjrQJeHCiBiCR24=";
    };
    "8.0.1" = {
      url = "https://github.com/wine-mono/wine-mono/releases/download/wine-mono-8.0.1/wine-mono-8.0.1-x86.msi";
      hash = "sha256-JyQAhfW0+LF1/wR589bMQwmwCtuzhsALof3dMPA2eXY=";
    };
    "7.4.1" = {
      url = "https://github.com/wine-mono/wine-mono/releases/download/wine-mono-7.4.1/wine-mono-7.4.1-x86.msi";
      hash = "sha256-RyHeAH7NABnMGOFEqILCkNozFNfhvHf1fEBGdeZEuf4=";
    };
    "7.0.0" = {
      url = "https://github.com/wine-mono/wine-mono/releases/download/wine-mono-7.0.0/wine-mono-7.0.0-x86.msi";
      hash = "sha256-s35vyeWQ5YIkPcJdcqX8wzDDp5cN/cmKeoHSOEW6iQA=";
    };
    "6.3.0" = {
      url = "https://github.com/wine-mono/wine-mono/releases/download/wine-mono-6.3.0/wine-mono-6.3.0-x86.msi";
      hash = "sha256-pfAtMqAoNpKkpiX1Qc+7tFGIMShHTFyANiOFMXzQmfA=";
    };
  };

  # https://gitlab.winehq.org/wine/wine/-/wikis/Wine-Mono
  wineMonoVersion =
    {
      "11.10" = "11.1.0";
      "11.8" = "11.1.0";
      "11.3" = "11.0.0";
      "11.1" = "11.0.0";
      "10.19" = "10.3.0";
      "10.18" = "10.3.0";
      "10.17" = "10.3.0";
      "10.16" = "10.2.0";
      "10.15" = "10.2.0";
      "10.14" = "10.2.0";
      "10.12" = "10.1.0";
      "10.10" = "10.1.0";
      "10.5" = "10.0.0";
      "10.0" = "9.4.0";
      "9.10" = "9.1.0";
      "8.13" = "8.0.1";
      "6.22" = "7.0.0";
      "6.14" = "6.3.0";
      "Proton8-26" = "8.0.1";
      "Proton8-25" = null;
      "Proton8-13" = null;
      "Proton7-36" = "7.0.0";
    }
    .${runtime.version} or null;

  needFramebuffer =
    {
      "11.10" = false;
      "11.8" = false;
      "11.3" = false;
      "11.1" = false;
      "10.19" = false;
      "10.18" = false;
      "10.17" = false;
      "10.16" = false;
      "10.15" = false;
      "10.14" = false;
      "10.12" = false;
      "10.10" = false;
      "10.5" = false;
      "10.0" = false;
      "9.10" = false;
      "8.13" = false;
      "6.22" = false;
      "6.14" = false;
      "Proton8-26" = false;
      "Proton8-25" = false;
      "Proton8-13" = false;
      "Proton7-36" = false;
    }
    .${runtime.version} or false;

  prefixWorkaroundCommands = lib.optionalString (runtime.version == "11.8") ''
    export WINEDLLOVERRIDES="winebth.sys=d''${WINEDLLOVERRIDES:+;$WINEDLLOVERRIDES}"
  '';

  wineMonoPatchCommands = lib.optionalString (wineMonoVersion == "11.1.0") ''
    # wine-mono 11.1.0's MSI link custom actions fail under the Nix build
    # sandbox with Wine 11.8. The payload and support MSI still install
    # cleanly without those deduplication/link actions.
    msibuild ./mono.msi -q "DELETE FROM InstallExecuteSequence WHERE Action = 'CREATELINKS'"
    msibuild ./mono.msi -q "DELETE FROM InstallExecuteSequence WHERE Action = 'CREATELINKS64'"
  '';

  wineBrowserCommands = ''
    ${coreutils}/bin/timeout --foreground 30s ${session.commands.wine} reg add 'HKCU\Software\Wine\WineBrowser' /v Browsers /t REG_SZ /d '${overlayfsLib.hostUrlOpener}/bin/nix-overlayfs-open-url' /f
    ${coreutils}/bin/timeout --foreground 30s ${session.commands.wineserver} --wait || true
  '';

  wine-mono =
    if (wineMonoVersion != null) then (fetchurl wineMonoDownloads.${wineMonoVersion}) else null;

  bootstrapCommands =
    prefixWorkaroundCommands
    +
    (lib.optionalString needFramebuffer ''
      # run virtual framebuffer
      Xvfb :999 -screen 0 1600x900x16 &
      XVFB_PROC_ID=$!
      export DISPLAY=:999
    '')
    + (lib.optionalString (wine-mono != null) ''
      # install mono
      echo "Installing mono..."
      ${session.commands.wine} start /wait "mono.msi"

      ${session.commands.wineserver} --wait
      echo "Mono installation finished."
    '')
    + (lib.optionalString (wine-mono == null) ''
      echo "Initialising wineprefix..."
      ${session.commands.wineboot}
      ${session.commands.wineserver} --wait
      echo "wineprefix initialised."
    '')
    + ''
      echo "Configuring WineBrowser host URL opener..."
      ${wineBrowserCommands}
    ''
    + (lib.optionalString (prefixInitCommands != "") ''
      ${prefixInitCommands}
    '')
    + (lib.optionalString needFramebuffer ''
      # terminate framebuffer
      kill $XVFB_PROC_ID
    '');
in
stdenv.mkDerivation {
  pname = "base-env";
  version = "0.0.1";

  nativeBuildInputs =
    with overlayfsLib.scripts;
    session.buildInputs
    ++ [
      xorg-server
      msitools
      reg2json
      json2reg
      jd-diff-patch
    ];

  src = wine-mono;

  unpackPhase = "true";

  buildPhase =
    (lib.optionalString (wine-mono != null) ''
      cp $src ./mono.msi
      ${wineMonoPatchCommands}
    ''
    + ''
      mkdir prefix home cache
      ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "export ${n}=${v}") session.env)}
      ${session.preCommands}
      export HOME=$(realpath ./home)
      export XDG_CACHE_HOME=$(realpath ./cache)
      export WINEPREFIX=$PWD/prefix

      echo "printing env..."
      env
      cat > ./bootstrap-prefix.sh <<'EOF'
      #!${stdenv.shell}
      set -euo pipefail

      ${bootstrapCommands}
      EOF
      chmod +x ./bootstrap-prefix.sh

      ./bootstrap-prefix.sh
    '')
    + ''
      ${session.postCommands}

      # convert registry to JSON, apply patches
      reg2json ./prefix/system.reg > ./system.json
      jd -f=merge -o ./prefix/system.json -p "${overlayfsLib.diffs.system}" "./system.json" || true
      json2reg ./prefix/system.json ./prefix/system.reg
      reg2json ./prefix/user.reg > ./prefix/user.json
      jd -f=merge -o ./prefix/user.json -p "${overlayfsLib.diffs.user}" "./user.json" || true
      json2reg ./prefix/user.json ./prefix/user.reg
      reg2json ./prefix/userdef.reg > ./prefix/userdef.json
      json2reg ./prefix/userdef.json ./prefix/userdef.reg

      # remove installer files
      rm --force ./prefix/drive_c/windows/Installer/*
      USERDIR="$(pwd)/prefix/drive_c/users/nixbld"
      echo "Removing links under $USERDIR"
      rm --recursive --force \
        $USERDIR/AppData/Roaming/Microsoft/Windows/Templates \
        $USERDIR/Documents \
        $USERDIR/Music \
        $USERDIR/Videos \
        $USERDIR/Desktop \
        $USERDIR/Pictures \
        $USERDIR/Downloads
    '';

  installPhase = ''
    mkdir --parents $out/basePackage
    mv ./prefix/* $out/basePackage/
  '';

  # mark package as non-executable
  meta.executableName = "";

  passthru = {
    inherit runtime wine-mono;
  };
}
