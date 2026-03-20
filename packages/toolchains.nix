{
  pkgs,
  versions,
  isAarch64,
}:
let
  mergeWineWithFexWineDlls =
    {
      wine,
      fexWineDlls,
    }:
    let
      lib = pkgs.lib;
      pname = "${if (wine ? pname) then wine.pname else "wine"}-with-fex-wine-dlls";
      version = if (wine ? version) then wine.version else lib.getVersion wine;
    in
    pkgs.runCommand pname
      {
        inherit version;
        meta = (wine.meta or { }) // {
          mainProgram = "wine";
        };
        passthru = (wine.passthru or { }) // {
          baseWine = wine;
          inherit fexWineDlls;
        };
      }
      ''
        cp -aL ${wine}/. "$out/"
        chmod -R u+w "$out"

        while IFS= read -r file; do
          substituteInPlace "$file" --replace-warn '${wine}' "$out"
        done < <(grep -RIl --fixed-strings '${wine}' "$out")

        install -Dm644 \
          ${fexWineDlls}/lib/wine/aarch64-windows/libarm64ecfex.dll \
          "$out/lib/wine/aarch64-windows/libarm64ecfex.dll"
        install -Dm644 \
          ${fexWineDlls}/lib/wine/aarch64-windows/libwow64fex.dll \
          "$out/lib/wine/aarch64-windows/libwow64fex.dll"
      '';

  llvmMingwArm64ec =
    if isAarch64 then
      pkgs.callPackage ./custom/llvm-mingw-arm64ec.nix {
        inherit versions;
      }
    else
      null;

  fexForWineDlls =
    if isAarch64 then
      pkgs.fex.overrideAttrs (_old: {
        version = versions.fexForWineDlls.version;
        src = pkgs.fetchgit {
          url = "https://github.com/FEX-Emu/FEX.git";
          inherit (versions.fexForWineDlls) rev hash;
          fetchSubmodules = true;
        };
      })
    else
      null;

  fexWineDlls =
    if isAarch64 then
      pkgs.callPackage ./custom/fex-wine-dlls.nix {
        inherit llvmMingwArm64ec;
        fex = fexForWineDlls;
      }
    else
      null;

  nativeArm64ecWine =
    if isAarch64 then
      pkgs.callPackage ./custom/wine-arm64ec.nix {
        inherit llvmMingwArm64ec versions;
      }
    else
      null;

  nativeArm64ecWineWithFex =
    if isAarch64 then
      mergeWineWithFexWineDlls {
        wine = nativeArm64ecWine;
        inherit fexWineDlls;
      }
    else
      null;
in
{
  inherit
    llvmMingwArm64ec
    fexForWineDlls
    fexWineDlls
    nativeArm64ecWine
    nativeArm64ecWineWithFex
    ;
}
