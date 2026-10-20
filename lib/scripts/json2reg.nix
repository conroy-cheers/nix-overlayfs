# Maintainer: Conroy Cheers <conroy@corncheese.org>
# Based on original work by Libor Štěpánek 2025
{
  writeShellScriptBin,
  jq,
  gnused,
}:
writeShellScriptBin "json2reg" ''
  # convert JSON to the .reg structure
  ${jq}/bin/jq --raw-output 'del(..|nulls) | "WINE REGISTRY Version \(.version)\n;; All keys relative to \(.location)\n\n#arch=\(.arch)\n",(.keys | to_entries[] | ("[\(.key)]", (if .value.__wine_link == "1" then "#link" else empty end), (.value | to_entries[] | select(.key != "__wine_link") | ("\(.key)=\(.value)")), ""))' < "$1" > "$2"

  # remove empty line at the end of the file
  ${gnused}/bin/sed -i '$ d' "$2"
''
