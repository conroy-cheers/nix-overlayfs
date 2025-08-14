{
  pkgs,
  nix-overlayfs,
  msxml4,
}:
nix-overlayfs.lib.mkWinePackage {
  pname = "halo-custom-edition";
  version = "1.00";
  src = pkgs.fetchurl {
    url = "http://halo1hub.com/downloads/setup/halocesetup_en_1.00.exe";
    hash = "sha256-TW8bm9s8LUP7pDrgAlf13+W1JeOHgHdrpG/ci3UKf7Y=";
  };
  ahkScript = ./install.ahk;
  overlayDependencies = [ msxml4 ];
  packageName = "halo-custom-edition";
}
