# Author: Libor Štěpánek 2025
# the base environment included with all mkWinpkgsPackage packages
{
  lib,
  stdenv,
  fetchurl,

  wine,
  xorg,
  jd-diff-patch,

  overlayfsLib,
}:
let
  wineMonoDownloads = {
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

  wineMonoVersion =
    {
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
    .${wine.version};

  needFramebuffer =
    {
      "10.15" = false;
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
    .${wine.version};

  wine-mono =
    if (wineMonoVersion != null) then (fetchurl wineMonoDownloads.${wineMonoVersion}) else null;
in
stdenv.mkDerivation {
  pname = "wine-base-env";
  version = "0.0.1";

  nativeBuildInputs = with overlayfsLib.scripts; [
    wine
    xorg.xorgserver
    reg2json
    json2reg
    jd-diff-patch
  ];

  src = wine-mono;

  unpackPhase = "true";

  buildPhase =
    (lib.optionalString (wine-mono != null) ''
      cp $src ./mono.msi
    '')
    + ''
      mkdir prefix home cache
      export HOME=$(realpath ./home)
      export XDG_CACHE_HOME=$(realpath ./cache)
      export WINEPREFIX=$PWD/prefix

      echo "printing env..."
      env
    ''
    + (lib.optionalString needFramebuffer ''
      # run virtual framebuffer
      Xvfb :999 -screen 0 1600x900x16 &
      XVFB_PROC_ID=$!
      export DISPLAY=:999
    '')
    + (lib.optionalString (wine-mono != null) ''
      # install mono
      echo "Installing mono..."
      ${lib.getExe wine} start /wait "mono.msi"

      wineserver --wait
      echo "Mono installation finished."
    '')
    + (lib.optionalString (wine-mono == null) ''
      echo "Initialising wineprefix..."
      ${lib.getExe wine} wineboot
      wineserver --wait
      echo "wineprefix initialised."
    '')
    + (lib.optionalString needFramebuffer ''
      # terminate framebuffer
      kill $XVFB_PROC_ID;
    '')
    + ''
      # convert registry to JSON, apply patches
      reg2json ./prefix/system.reg > ./system.json
      jd -f=merge -o ./prefix/system.json -p "${overlayfsLib.diffs.system}" "./system.json" || true
      json2reg ./prefix/system.json ./prefix/system.reg
      reg2json ./prefix/user.reg > ./prefix/user.json
      jd -f=merge -o ./prefix/system.json -p "${overlayfsLib.diffs.user}" "./user.json" || true
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
    inherit wine wine-mono;
  };
}
