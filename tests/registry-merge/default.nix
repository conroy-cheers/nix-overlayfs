{
  pkgs,
  overlayfsLib,
}:
pkgs.stdenv.mkDerivation {
  pname = "registry-merge-test";
  version = "1.0.0";

  nativeBuildInputs = [
    overlayfsLib.scripts.mergeWineRegistries
    overlayfsLib.scripts.reg2json
    pkgs.jq
  ];

  unpackPhase = "true";

  buildPhase = ''
    mkdir dep base app out

    cat > dep/system.reg <<'EOF'
WINE REGISTRY Version 2
;; All keys relative to REGISTRY\\Machine

#arch=win64

[Software\\Layered]
"dep"="dep"
"winner"="dep"
EOF

    cat > base/system.reg <<'EOF'
WINE REGISTRY Version 2
;; All keys relative to REGISTRY\\Machine

#arch=win64

[Software\\Layered]
"base"="base"
"winner"="base"

[Software\\BaseOnly]
"present"="1"
EOF

    cat > app/system.reg <<'EOF'
WINE REGISTRY Version 2
;; All keys relative to REGISTRY\\Machine

#arch=win64

[Software\\Layered]
"app"="app"
"winner"="app"
EOF

    cat > dep/user.reg <<'EOF'
WINE REGISTRY Version 2
;; All keys relative to REGISTRY\\User\\S-1-5-21-0-0-0-1000

#arch=win64

[Software\\UserLayer]
"dep"="dep"
EOF

    cat > app/user.reg <<'EOF'
WINE REGISTRY Version 2
;; All keys relative to REGISTRY\\User\\S-1-5-21-0-0-0-1000

#arch=win64

[Software\\UserLayer]
"app"="app"
EOF

    merge-wine-registries out dep base app

    reg2json out/system.reg > system.json
    reg2json out/user.reg > user.json

    jq -e '
      .keys["Software\\\\Layered"]["\"dep\""] == "\"dep\"" and
      .keys["Software\\\\Layered"]["\"base\""] == "\"base\"" and
      .keys["Software\\\\Layered"]["\"app\""] == "\"app\"" and
      .keys["Software\\\\Layered"]["\"winner\""] == "\"app\"" and
      .keys["Software\\\\BaseOnly"]["\"present\""] == "\"1\""
    ' system.json

    jq -e '
      .keys["Software\\\\UserLayer"]["\"dep\""] == "\"dep\"" and
      .keys["Software\\\\UserLayer"]["\"app\""] == "\"app\""
    ' user.json

    [ ! -e out/userdef.reg ]
  '';

  installPhase = "touch $out";
}
