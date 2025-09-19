# Author: Libor Štěpánek 2025
# the base environment included with all mkWinpkgsPackage packages
{
  lib,
  stdenv,
  fetchurl,

  wine,
  xorg,
  jd-diff-patch,

  nix-overlayfs,
}:
let
  wineMonoDownloads = {
    "9.4.0" = {
      url = "https://github.com/wine-mono/wine-mono/releases/download/wine-mono-9.4.0/wine-mono-9.4.0-x86.msi";
      hash = "sha256-z2FzrpS3np3hPZp0zbJWCohvw9Jx+Uiayxz9vZYcrLI=";
    };
    "10.0.0" = {
      url = "https://github.com/wine-mono/wine-mono/releases/download/wine-mono-10.0.0/wine-mono-10.0.0-x86.msi";
      hash = "";
    };
    "10.1.0" = {
      url = "https://github.com/wine-mono/wine-mono/releases/download/wine-mono-10.1.0/wine-mono-10.1.0-x86.msi";
      hash = "sha256-yIwkMYkLwyys7I1+pw5Tpa5LlcjFXKbnXvjbDkzPEHA=";
    };
  };

  wineMonoVersion =
    {
      "10.14" = "10.2.0";
      "10.12" = "10.1.0";
      "10.10" = "10.1.0";
      "10.5" = "10.0.0";
      "10.0" = "9.4.0";
    }
    .${wine.version};

  needFramebuffer =
    {
      "10.0" = false;
    }
    .${wine.version};

  wine-mono = fetchurl wineMonoDownloads.${wineMonoVersion};
in
stdenv.mkDerivation {
  pname = "wine-base-env";
  version = "0.0.1";

  nativeBuildInputs = with nix-overlayfs.lib.scripts; [
    wine
    xorg.xorgserver
    reg2json
    json2reg
    jd-diff-patch
  ];

  src = wine-mono;

  unpackPhase = "true";

  buildPhase = ''
    mkdir prefix home cache
    export HOME=$(realpath ./home)
    export XDG_CACHE_HOME=$(realpath ./cache)
    export WINEPREFIX=$PWD/prefix
  ''
  + (lib.optionalString needFramebuffer ''
    # run virtual framebuffer
    Xvfb :999 -screen 0 1600x900x16 &
    XVFB_PROC_ID=$!
    export DISPLAY=:999
  '')
  + ''
    # install mono
    echo "Installing mono..."
    ${lib.getExe wine} "$src"

    wineserver --wait
    echo "Mono installation finished."
  ''
  + (lib.optionalString needFramebuffer ''
    # terminate framebuffer
    kill $XVFB_PROC_ID;
  '')
  + ''
    # convert registry to JSON, apply patches
    reg2json ./prefix/system.reg > ./system.json
    jd -f=merge -o ./prefix/system.json -p "${nix-overlayfs.lib.diffs.system}" "./system.json" || true
    json2reg ./prefix/system.json ./prefix/system.reg
    reg2json ./prefix/user.reg > ./prefix/user.json
    jd -f=merge -o ./prefix/system.json -p "${nix-overlayfs.lib.diffs.user}" "./user.json" || true
    json2reg ./prefix/user.json ./prefix/user.reg
    reg2json ./prefix/userdef.reg > ./prefix/userdef.json
    json2reg ./prefix/userdef.json ./prefix/userdef.reg

    # remove installer files
    rm ./prefix/drive_c/windows/Installer/*
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
