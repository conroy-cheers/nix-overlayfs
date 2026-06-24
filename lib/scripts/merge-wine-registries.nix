{ stdenv }:
stdenv.mkDerivation {
  pname = "merge-wine-registries";
  version = "1.0.0";

  src = ./merge-wine-registries.cpp;
  dontUnpack = true;

  buildPhase = ''
    runHook preBuild
    $CXX -std=c++17 -O2 "$src" -o merge-wine-registries
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 merge-wine-registries "$out/bin/merge-wine-registries"
    runHook postInstall
  '';
}
