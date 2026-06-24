{
  pkgs,
  overlayfsLib,
}:
let
  basePackage = pkgs.stdenvNoCC.mkDerivation {
    pname = "post-launch-cleanup-base";
    version = "1.0.0";

    dontUnpack = true;

    installPhase = ''
      mkdir -p "$out"
    '';
  };

  package = overlayfsLib.mkOverlayfsPackage {
    inherit basePackage;
    executableName = "post-launch-cleanup";
    executablePath = "/drive_c/windows/system32/notepad.exe";
    launchProgram = "${pkgs.coreutils}/bin/false";
    extraPostLaunchCommands = ''
      printf '%s\n' post-launch-sentinel >> "$state_dir/post-launch-cleanup-test"
    '';
  };
in
pkgs.stdenv.mkDerivation {
  pname = "post-launch-cleanup-test";
  version = "1.0.0";

  unpackPhase = "true";

  buildPhase = ''
    script="${package}/libexec/post-launch-cleanup-setupEnv.sh"

    grep -F 'nix_overlayfs_post_launch_ran=0' "$script"
    grep -F 'nix_overlayfs_run_post_launch_once()' "$script"
    grep -F 'nix_overlayfs_run_post_launch_once || true' "$script"
    grep -F 'trap cleanup_runtime_session EXIT' "$script"
    grep -F 'post-launch-sentinel' "$script"

    normal_exit_calls="$(grep -Ec '^[[:space:]]*nix_overlayfs_run_post_launch_once$' "$script")"
    test "$normal_exit_calls" -eq 2
  '';

  installPhase = "touch $out";
}
