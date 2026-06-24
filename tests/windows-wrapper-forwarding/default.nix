{
  pkgs,
  ...
}:
pkgs.stdenvNoCC.mkDerivation {
  pname = "windows-wrapper-forwarding-test";
  version = "1.0.0";

  dontUnpack = true;

  buildPhase = ''
    mk_windows_package=${../../lib/mkWindowsPackage.nix}
    base_env=${../../packages/wine-modules/wine-base-env/default.nix}

    grep -F 'extraPostLaunchCommands ? ""' "$mk_windows_package"
    grep -F 'inherit extraPostLaunchCommands;' "$mk_windows_package"

    sed -n '/needFramebuffer =/,/\.''${runtime.version};/p' "$base_env" > need-framebuffer-map
    for version in 11.10 11.8 11.3 11.1 10.19 10.18 10.17 10.16 10.15 10.14 10.12 10.10 10.5 10.0 9.10 8.13 6.22 6.14 Proton8-26 Proton8-25 Proton8-13 Proton7-36; do
      grep -F "\"$version\" = " need-framebuffer-map
    done
  '';

  installPhase = "touch $out";
}
