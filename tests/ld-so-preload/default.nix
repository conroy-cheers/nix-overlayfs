{
  pkgs,
  overlayfsLib,
}:
let
  basePackage = pkgs.stdenvNoCC.mkDerivation {
    pname = "ld-so-preload-base";
    version = "1.0.0";

    dontUnpack = true;

    installPhase = ''
      mkdir -p "$out"
    '';
  };

  fakeSession = {
    env = { };
    preCommands = ''
      printf '%s\n' session-precommands
    '';
    postCommands = "";
    commands = {
      wine = "${pkgs.coreutils}/bin/false";
      wineserver = "${pkgs.coreutils}/bin/false";
    };
  };

  package = overlayfsLib.mkOverlayfsPackage {
    inherit basePackage;
    executableName = "ld-so-preload";
    executablePath = "/drive_c/windows/system32/notepad.exe";
    launchProgram = "${pkgs.coreutils}/bin/false";
    session = fakeSession;
  };
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "ld-so-preload-test";
  version = "1.0.0";

  nativeBuildInputs = [
    pkgs.gawk
    pkgs.gnugrep
  ];

  dontUnpack = true;

  buildPhase = ''
    script="${package}/libexec/ld-so-preload-setupEnv.sh"

    grep -F 'nix_overlayfs_hide_ld_so_preload()' "$script"
    grep -F 'NIX_OVERLAYFS_PRESERVE_LD_SO_PRELOAD:-0' "$script"
    grep -F '[ ! -f /etc/ld.so.preload ]' "$script"
    grep -F ': > "$tempdir/empty-ld.so.preload"' "$script"
    grep -F 'mount --bind "$tempdir/empty-ld.so.preload" /etc/ld.so.preload' "$script"
    grep -F 'warning: failed to hide /etc/ld.so.preload in Wine mount namespace' "$script"
    grep -F 'nix_overlayfs_launch_application()' "$script"
    grep -F 'nix_overlayfs_prepare_launch_session()' "$script"
    grep -F 'nix_overlayfs_run_launch_loop()' "$script"
    grep -F 'nix_overlayfs_launch_application "$tempdir/overlay//drive_c/windows/system32/notepad.exe" "$@"' "$script"

    awk '
      /^[[:space:]]*nix_overlayfs_hide_ld_so_preload$/ && !hide_call { hide_call = NR }
      /session-precommands/ && !precommands { precommands = NR }
      /^[[:space:]]*nix_overlayfs_prepare_launch_session$/ && !prepare { prepare = NR }
      END {
        if (!hide_call || !precommands || !prepare || hide_call >= precommands || hide_call >= prepare) {
          print "ld.so.preload masking must run before session precommands and Wine registry helpers" > "/dev/stderr"
          exit 1
        }
      }
    ' "$script"
  '';

  installPhase = "touch $out";
}
