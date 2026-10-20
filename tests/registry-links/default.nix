{ pkgs, overlayfsLib }:
pkgs.runCommand "wine-registry-link-roundtrip"
  {
    nativeBuildInputs = [
      overlayfsLib.scripts.reg2json
      overlayfsLib.scripts.json2reg
      overlayfsLib.scripts.mergeWineRegistries
      pkgs.jq
    ];
  }
  ''
      mkdir base app merged
      cat > base/system.reg <<'EOF'
    WINE REGISTRY Version 2
    ;; All keys relative to REGISTRY\\Machine

    #arch=win64

    [Alias]
    #link
    "SymbolicLinkValue"=hex(6):5c,00,52,00,\
      65,00,67,00

    [Ordinary]
    "value"="unchanged"
    EOF
      reg2json base/system.reg > before.json
      jq -e '.keys.Alias.__wine_link == "1" and .keys.Ordinary.__wine_link == null' before.json
      json2reg before.json restored.reg
      test "$(grep -c '^#link$' restored.reg)" = 1
      ! grep -q '__wine_link' restored.reg
      reg2json restored.reg > after.json
      diff <(jq -S . before.json) <(jq -S . after.json)

      cat > app/system.reg <<'EOF'
    WINE REGISTRY Version 2
    ;; All keys relative to REGISTRY\\Machine

    #arch=win64

    [Ordinary]
    "added"="layer"
    EOF
      merge-wine-registries merged base app
      test "$(grep -c '^#link$' merged/system.reg)" = 1
      ! grep -q '__wine_link' merged/system.reg
      reg2json merged/system.reg > merged.json
      jq -e '.keys.Alias.__wine_link == "1" and .keys.Ordinary["\"added\""] == "\"layer\""' merged.json
      touch "$out"
  ''
