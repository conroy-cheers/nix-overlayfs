{
  lib,
  __splicedPackages,
  runtime,
  overlayfsLib,
}:

let
  pkgs = __splicedPackages;
  inherit (lib) makeExtensible;

  callPackageWithScope =
    scope: drv: args:
    lib.callPackageWith scope drv args;
  mkScope = scope: pkgs // scope;

  packages =
    self:
    let
      runtimeWithLayers = runtime // {
        baseEnvLayer = self.base-env;
        selectBaseEnvLayer =
          {
            hostIntegration ? true,
            managedRuntime ? "auto",
          }:
          if hostIntegration then
            if managedRuntime == "disabled" then self.base-env-no-managed-runtime else self.base-env
          else if managedRuntime == "disabled" then
            self.base-env-headless
          else
            self.base-env-no-host-integration;
        autohotkeyLayer = self.autohotkey;
      };
      defaultScope = mkScope self;
      callPackage =
        drv: args: callPackageWithScope (defaultScope // { runtime = runtimeWithLayers; }) drv args;
    in
    rec {
      inherit overlayfsLib callPackage;
      runtime = runtimeWithLayers;

      base-env = callPackage ./wine-base-env { };
      base-env-headless = callPackage ./wine-base-env {
        hostIntegration = false;
        managedRuntime = "disabled";
      };
      base-env-no-host-integration = callPackage ./wine-base-env {
        hostIntegration = false;
      };
      base-env-no-managed-runtime = callPackage ./wine-base-env {
        managedRuntime = "disabled";
      };
      autohotkey = callPackage ./autohotkey { };
      crypt32 = callPackage ./crypt32 { };
      dotnet-framework-4-8 = callPackage ./dotnet-framework-4-8 { };
      fonts = callPackage ./fonts { };
      gecko = callPackage ./wine-gecko { pkgs = pkgs; };
      dxvk = callPackage ./wine-dxvk { dxvk = pkgs.dxvk; };
      dxvk_2_6_2 = callPackage ./wine-dxvk {
        dxvk = pkgs.stdenvNoCC.mkDerivation {
          pname = "dxvk";
          version = "2.6.2";
          src = pkgs.fetchzip {
            url = "https://github.com/doitsujin/dxvk/releases/download/v2.6.2/dxvk-2.6.2.tar.gz";
            sha256 = "1vfw4amwbs5b007vlfrr8lir3r7kxbhk5gi6wk4wynfa8ly4sj77";
          };
          dontConfigure = true;
          dontBuild = true;
          installPhase = ''
            runHook preInstall
            mkdir -p "$out"
            cp -r "$src"/. "$out"/
            runHook postInstall
          '';
        };
        packageName = "dxvk-2.6.2";
      };
      mfc42 = callPackage ./mfc42 { };
      mingw = callPackage ./mingw { };
      msvcp60 = callPackage ./msvcp60 { };
      msxml4 = callPackage ./msxml4 { };
      msxml6 = callPackage ./msxml6 { };
      vcrun2022 = callPackage ./vcrun2022 { };
      webview2 = callPackage ./webview2 { };
      win10 = callPackage ./win10 { };
      win11 = callPackage ./win11 { };
    };
in
makeExtensible packages
