{
  pkgs,
  overlayfsLib,
}:
pkgs.stdenv.mkDerivation {
  pname = "host-url-opener-test";
  version = "1.0.0";

  nativeBuildInputs = [
    overlayfsLib.hostUrlOpener
  ];

  unpackPhase = "true";

  buildPhase = ''
    mkdir requests
    export NIX_OVERLAYFS_HOST_OPEN_DIR="$PWD/requests"

    nix-overlayfs-open-url 'https://example.invalid/login?state=abc'

    request_count="$(find requests -maxdepth 1 -type f -name 'request.*' | wc -l)"
    [ "$request_count" -eq 1 ]

    request_file="$(find requests -maxdepth 1 -type f -name 'request.*' -print -quit)"
    [ "$(cat "$request_file")" = 'https://example.invalid/login?state=abc' ]
  '';

  installPhase = "touch $out";
}
