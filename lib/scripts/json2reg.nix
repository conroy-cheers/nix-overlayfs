# Author: Libor Štěpánek 2025
{
  writeShellScriptBin,
  jq,
  gnused,
}:
writeShellScriptBin "json2reg" ''
  # convert JSON to the .reg structure
  ${jq}/bin/jq --raw-output 'del(..|nulls) | "WINE REGISTRY Version \(.version)\n;; All keys relative to \(.location)\n\n#arch=\(.arch)\n",(.keys | to_entries[] | ("[\(.key)]", (.value | to_entries[] | ("\(.key)=\(.value)")), ""))' < "$1" > "$2"
  
  # remove empty line at the end of the file
  ${gnused}/bin/sed -i '$ d' "$2"
''
