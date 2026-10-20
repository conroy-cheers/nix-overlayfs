{ stdenv, python3 }:
stdenv.mkDerivation {
  pname = "wine-portable-reparse";
  version = "1";
  src = ./portable-reparse.c;
  dontUnpack = true;
  buildPhase = ''
    $CC -Wall -Wextra -Werror -shared -fPIC "$src" -o libwine-portable-reparse.so -ldl
  '';
  installPhase = ''
    install -Dm755 libwine-portable-reparse.so "$out/lib/libwine-portable-reparse.so"
    mkdir -p "$out/bin"
    printf '#!${python3}/bin/python3\n' > "$out/bin/normalize-wine-reparse.py"
    cat ${./normalize-reparse.py} >> "$out/bin/normalize-wine-reparse.py"
    chmod +x "$out/bin/normalize-wine-reparse.py"
  '';
}
