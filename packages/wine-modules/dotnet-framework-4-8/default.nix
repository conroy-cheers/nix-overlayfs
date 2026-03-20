# Maintainer: Conroy Cheers <conroy@corncheese.org>
# Based on original work by Libor Štěpánek 2025
# example of a non-executable package
{
  runtime,
  overlayfsLib,
}:
overlayfsLib.mkWinpkgsPackage {
  inherit runtime;
  packageName = "Microsoft/DotNet/Framework/DeveloperPack_4"; # the package name can represent a longer folder structure
  version = "4.8";
}
