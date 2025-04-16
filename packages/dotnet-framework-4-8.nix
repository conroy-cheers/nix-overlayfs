# Author: Libor Štěpánek 2025
# example of a non-executable package
{
  self,
  pkgs,
}:
self.outputs.lib.mkWinpkgsPackage {
  inherit pkgs;
  packageName = "Microsoft/DotNet/Framework/DeveloperPack_4"; # the package name can represent a longer folder structure
  version = "4.8";
}
