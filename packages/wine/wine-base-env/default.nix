# Author: Libor Štěpánek 2025
# the base environment included with all mkWinpkgsPackage packages
{
  lib,
  pkgs,
  stdenv,

  wine,
  wine-mono,
  xorg,
  jd-diff-patch,

  nix-overlayfs,
}:
stdenv.mkDerivation {
  pname = "wine-base-env";
  version = "0.0.1";

  nativeBuildInputs =
    with nix-overlayfs.lib.scripts;
    [
      wine
      xorg.xorgserver
      reg2json
      json2reg
      jd-diff-patch
    ];

  src = wine-mono;

  unpackPhase = "true";

  buildPhase = ''
    cp $src ./mono.msi
    mkdir prefix home cache
    export HOME=$(realpath ./home)
    export XDG_CACHE_HOME=$(realpath ./cache)
    export WINEPREFIX=$PWD/prefix

    # run virtual framebuffer
    Xvfb :999 -screen 0 1600x900x16 &
    XVFB_PROC_ID=$!
    export DISPLAY=:999

    # install mono
    ${lib.getExe wine} start /wait "mono.msi"

    wineserver --wait

    # terminate framebuffer
    kill $XVFB_PROC_ID;

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
}
