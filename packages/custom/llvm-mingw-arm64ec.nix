{
  autoPatchelfHook,
  stdenvNoCC,
  stdenv,
  fetchurl,
  lib,
  versions,
}:
let
  release = versions.llvmMingwArm64ec;
in
stdenvNoCC.mkDerivation rec {
  pname = "llvm-mingw-arm64ec";
  inherit (release) version;

  src = fetchurl {
    inherit (release) url hash;
  };

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R ./* "$out"/
    runHook postInstall
  '';

  meta = {
    description = "llvm-mingw toolchain with arm64ec target support";
    homepage = "https://github.com/mstorsjo/llvm-mingw";
    license = lib.licenses.mit;
    platforms = [ "aarch64-linux" ];
  };
}
