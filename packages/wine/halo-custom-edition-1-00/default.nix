{
  pkgs,
  fetchurl,
  nix-overlayfs,
  msvcp60,
  msxml4,
  wine,
}:
nix-overlayfs.lib.mkWinePackage {
  inherit wine;
  pname = "halo-custom-edition";
  version = "1.00";
  src = fetchurl {
    url = "http://halo1hub.com/downloads/setup/halocesetup_en_1.00.exe";
    hash = "sha256-TW8bm9s8LUP7pDrgAlf13+W1JeOHgHdrpG/ci3UKf7Y=";
  };
  ahkScript = builtins.readFile ./install.ahk;
  overlayDependencies = [ msvcp60 msxml4 ];
  packageName = "halo-custom-edition";
  executableName = "haloce";
  executablePath = "/drive_c/Program Files (x86)/Microsoft Games/Halo Custom Edition/haloce.exe";
  # launchVncServer = true;
}
