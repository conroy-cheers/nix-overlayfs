{ pkgs, ... }:
let
  modules = pkgs.nix-overlayfs.moduleScopes.makeNativeModules {
    wine = pkgs.wineWow64Packages.unstableFull // { version = "11.4"; };
    windowsArch = "wow64";
  };
in
assert modules.base-env.wine-mono != null;
assert modules.base-env.wine-mono.name == "wine-mono-11.0.0-x86.msi";
pkgs.runCommand "wine-11-4-mono-selection" { } ''
  touch "$out"
''
