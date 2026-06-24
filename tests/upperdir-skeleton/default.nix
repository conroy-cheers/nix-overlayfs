{
  pkgs,
  overlayfsLib,
}:
let
  basePackage = pkgs.stdenvNoCC.mkDerivation {
    pname = "upperdir-skeleton-base";
    version = "1.0.0";

    dontUnpack = true;

    installPhase = ''
      mkdir -p \
        "$out/drive_c/users/Public" \
        "$out/drive_c/Program Files (x86)/Vendor/App/controls"
    '';
  };

  package = overlayfsLib.mkOverlayfsPackage {
    inherit basePackage;
    executableName = "upperdir-skeleton";
    executablePath = "/drive_c/windows/system32/notepad.exe";
    launchProgram = "${pkgs.coreutils}/bin/false";
  };
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "upperdir-skeleton-test";
  version = "1.0.0";

  nativeBuildInputs = [
    pkgs.gawk
    pkgs.gnugrep
  ];

  dontUnpack = true;

  buildPhase = ''
    script="${package}/libexec/upperdir-skeleton-setupEnv.sh"

    grep -F 'nix_overlayfs_prepare_upperdir_skeleton()' "$script"
    grep -F 'find "$lower_drive_c" -maxdepth 5 -type d -print0' "$script"
    grep -F 'chmod a+rwx "$appdir/$relative_dir" || true' "$script"

    awk '
      /^[[:space:]]*nix_overlayfs_prepare_upperdir_skeleton$/ && !prepare { prepare = NR }
      /fuse-overlayfs/ && !mount { mount = NR }
      END {
        if (!prepare || !mount || prepare >= mount) {
          print "upperdir skeleton must be prepared before mounting fuse-overlayfs" > "/dev/stderr"
          exit 1
        }
      }
    ' "$script"
  '';

  installPhase = "touch $out";
}
