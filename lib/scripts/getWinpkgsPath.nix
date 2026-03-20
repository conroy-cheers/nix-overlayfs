# Maintainer: Conroy Cheers <conroy@corncheese.org>
# Based on original work by Libor Štěpánek 2025
{ pkgs }:
let
  winpkgs = builtins.fetchGit {
    url = "https://github.com/microsoft/winget-pkgs";
    ref = "master";
    rev = "3d7993994fab4d4f8bb43bbb4b34e0abf280655f";
  };
in
pkgs.writeShellScript "getWinpkgsPath.sh" ''
  winpkgs="${winpkgs}/manifests"

  if [ $# -lt 1 ]; then
      exit 1
  fi

  appname="$1"
  manifestId="''${appname//\//.}"

  # get the name of the first directory (first letter of the author, lowercased)
  bucket="''${appname:0:1}"

  # join bucket to the original identifier
  pkgPath="$winpkgs/''${bucket,,}/$appname"

  # check for the existence of the path
  if [ ! -d "$pkgPath" ]; then
      exit 1
  fi

  # get the version directory, find latest if unspecified
  if [ $# -lt 2 ] || [ "$2" == latest ]; then
      latest=$(
          find "$pkgPath" -type f -name "$manifestId.installer.yaml" -printf '%h\n' \
            | sort --version-sort --reverse \
            | head --lines 1
      )
      if [ -z "$latest" ]; then
          exit 1
      fi
      pkgPath="$latest"
  elif [ -d "$pkgPath/$2" ]; then
      pkgPath="$pkgPath/$2"
  else
      exit 1
  fi

  # find manifest file
  manifest="$pkgPath/$manifestId.installer.yaml"

  if [ ! -f "$manifest" ]; then
      exit 1
  fi

  # convert manifest to JSON
  yj < "$manifest" > $out
''
