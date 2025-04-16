# Author: Libor Štěpánek 2025
{writeShellScriptBin}:
writeShellScriptBin "reg2json" ''
  shopt -s patsub_replacement

  INSIDE_ENTRY=0
  PARTIAL_ENTRY=0
  HAS_VERSION=0
  HAS_ARCH=0
  HAS_LOCATION=0
  HAS_HEADER=0
  REGEX_VERSION="WINE REGISTRY Version ([0-9]+)"
  REGEX_ARCH="#arch=(.*)"
  REGEX_LOCATION=";; All keys relative to (.*)"
  REGEX_HKEY="^\[(.*)\]( [0-9]+)?$"
  REGEX_VALUE="^([^=]+)=(.+)$"
  VALUE_ISFIRST=1
  KEY_ISFIRST=1
  COMMA=","

  printf "{"

  while read -r LINE; do
      if [[ "$LINE" == "#"* ]] && [[ "$LINE" != "#arch"* ]]; then
          continue
      fi

      if [[ $HAS_HEADER == 1 ]]; then

          # phase 3 end: close object if there are no more values
          if [[ "$LINE" =~ ^\ *$ ]]; then
              if [[ $INSIDE_ENTRY == 1 ]]; then
                  printf "},"
              fi
              INSIDE_ENTRY=0
              VALUE_ISFIRST=1

          # phase 3: scan for key-value pairs
          elif [[ $INSIDE_ENTRY == 1 ]]; then

              # continue previous key
              if [[ $PARTIAL_ENTRY == 1 ]]; then
                  PARTIAL_ENTRY=0
                  if [[ ''${LINE: -1} == "\\" ]]; then
                      PARTIAL_ENTRY=1
                      printf "\\\n  %s\\" "$LINE"
                  else
                      printf "\\\n  %s\"" "$LINE"
                  fi

              # check if line is a key-value pair
              elif [[ "$LINE" =~ $REGEX_VALUE ]]; then
                  INSIDE_ENTRY=1

                  #escape backslashes and double quotes
                  KEY="''${BASH_REMATCH[1]}"
                  KEY=''${KEY//[\\\"]/\\&}
                  VALUE="''${BASH_REMATCH[2]}"
                  VALUE=''${VALUE//[\\\"]/\\&}

                  # avoid trailing commas
                  if [[ $VALUE_ISFIRST == 1 ]]; then
                      COMMA=""
                      VALUE_ISFIRST=0
                  else
                      COMMA=","
                  fi

                  # check if value continues on the next line
                  if [[ ''${VALUE: -1} == "\\" ]]; then
                      PARTIAL_ENTRY=1
                      printf "%s\"%s\":\"%s" "$COMMA" "$KEY" "$VALUE"
                  else
                      printf "%s\"%s\":\"%s\"" "$COMMA" "$KEY" "$VALUE"
                  fi
              else
                  exit 1
              fi

          # phase 2: scan for entries
          elif [[ $INSIDE_ENTRY == 0 ]]; then
              if [[ "$LINE" =~ $REGEX_HKEY ]]; then
                  INSIDE_ENTRY=1
                  VALUE="''${BASH_REMATCH[1]}"
                  VALUE=''${VALUE//[\\\"]/\\&}
                  if [[ $KEY_ISFIRST == 1 ]]; then
                      printf "\"keys\":{"
                      KEY_ISFIRST=0
                  fi

                  printf "\"%s\":{" "$VALUE"
              else
                  exit 1
              fi
          fi
      else
          # phase 1: scan for metadata
          if [[ "$LINE" =~ $REGEX_VERSION ]]; then
              printf "\"version\":\"%s\"," "''${BASH_REMATCH[1]}"
              HAS_VERSION=1
          elif [[ "$LINE" =~ $REGEX_ARCH ]]; then
              printf "\"arch\":\"%s\"," "''${BASH_REMATCH[1]}"
              HAS_ARCH=1
          elif [[ "$LINE" =~ $REGEX_LOCATION ]]; then
              printf "\"location\":\"%s\"," "''${BASH_REMATCH[1]//[\\\"]/\\&}"
              HAS_LOCATION=1
          fi

          if [[ $HAS_ARCH == 1 ]] && [[ $HAS_VERSION == 1 ]] && [[ $HAS_LOCATION == 1 ]]; then
              HAS_HEADER=1
          fi
      fi
  done < "$1"

  if [[ $INSIDE_ENTRY == 1 ]]; then
      printf "}"
  fi

  # close the JSON object
  printf "}}"
''
