{
  stdenv,
  fuse3,
  util-linux,
}:
stdenv.mkDerivation {
  pname = "nix-overlayfs-runtime-supervisor";
  version = "1.0.0";

  src = ./runtime-supervisor.c;
  dontUnpack = true;

  strictDeps = true;

  buildPhase = ''
    runHook preBuild
    $CC \
      -std=c11 -O2 -Wall -Wextra -Werror \
      -DFUSERMOUNT3_PATH='"${fuse3}/bin/fusermount3"' \
      -DMOUNTPOINT_PATH='"${util-linux}/bin/mountpoint"' \
      -DUMOUNT_PATH='"${util-linux}/bin/umount"' \
      "$src" -o nix-overlayfs-runtime-supervisor
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 nix-overlayfs-runtime-supervisor \
      "$out/bin/nix-overlayfs-runtime-supervisor"
    runHook postInstall
  '';
}
