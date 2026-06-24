{
  pkgs,
  ...
}:
pkgs.stdenvNoCC.mkDerivation {
  pname = "base-env-user-diff-test";
  version = "1.0.0";

  dontUnpack = true;

  buildPhase = ''
    base_env=${../../packages/wine-modules/wine-base-env/default.nix}

    grep -F 'jd -f=merge -o ./prefix/user.json -p "''${overlayfsLib.diffs.user}" "./user.json"' "$base_env"
    if grep -Fq 'jd -f=merge -o ./prefix/system.json -p "''${overlayfsLib.diffs.user}" "./user.json"' "$base_env"; then
      echo "user registry diff must not be written to system.json" >&2
      exit 1
    fi
  '';

  installPhase = "touch $out";
}
