# Author: Libor Štěpánek 2025
{pkgs}: let
  winpkgs = builtins.fetchGit {
    url = "https://github.com/microsoft/winget-pkgs";
    ref = "master";
    rev = "8cd2ee09a77bbb9d803f21d4c41b8953f57f75e0";
  };
in
  pkgs.writeShellScript "getWinpkgsPath.sh" ''
    winpkgs="${winpkgs}/manifests"

    if [ $# -lt 1 ]; then
        exit 1
    fi

    appname="$1"

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
        latest=$(find "$pkgPath" -type d | sort --version-sort --reverse | head --lines 1)
        pkgPath="$latest"
    elif [ -d "$pkgPath/$2" ]; then
        pkgPath="$pkgPath/$2"
    else
        exit 1
    fi

    # find manifest file
    manifest=$(find "$pkgPath" -type f -name "*installer.yaml")

    if [ ! -f "$manifest" ]; then
        exit 1
    fi

    # convert manifest to JSON
    yj < "$manifest" > $out
  ''
