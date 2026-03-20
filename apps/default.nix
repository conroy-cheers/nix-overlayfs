{
  pkgs,
  packageScopes,
  overlayfsLib,
}:
let
  lib = pkgs.lib;
  isAarch64 = pkgs.stdenv.hostPlatform.isAarch64;
  appCatalog = import ./catalog.nix {
    inherit pkgs overlayfsLib;
  };
  policy = import ./policy.nix { inherit pkgs; };

  mkApp = pkg: {
    type = "app";
    program = "${pkg}/bin/${pkg.meta.executableName}";
  };

  runtimeNamespaces = lib.filterAttrs (_: modules: modules != null) (
    {
      native = packageScopes.nativeModules or null;
    }
    // lib.optionalAttrs isAarch64 {
      x64Fex = packageScopes.x64FexModules or null;
    }
  );

  binaryVariantByNamespace =
    if isAarch64 then
      {
        native = "arm64";
        x64Fex = "x64";
      }
    else
      {
        native = "x64";
      };

  buildNamespacePackages =
    namespace: modules:
    lib.concatMapAttrs (
      appName: appSpec:
      let
        binaryVariant = binaryVariantByNamespace.${namespace};
      in
      if builtins.hasAttr binaryVariant appSpec.variants then
        {
          ${appName} = appSpec.variants.${binaryVariant} modules;
        }
      else
        { }
    ) appCatalog;

  namespacedPackages = lib.mapAttrs buildNamespacePackages runtimeNamespaces;

  appAvailableInNamespace =
    appName: namespace:
    builtins.hasAttr namespace namespacedPackages
    && builtins.hasAttr appName namespacedPackages.${namespace};

  preferredNamespaceFor =
    appName:
    let
      requested = policy.preferredNamespaceByApp.${appName} or null;
      fallbackOrder = if isAarch64 then [ "x64Fex" "native" ] else [ "native" ];
      availableFallbacks = builtins.filter (namespace: appAvailableInNamespace appName namespace) fallbackOrder;
    in
    if requested != null && appAvailableInNamespace appName requested then
      requested
    else if availableFallbacks == [ ] then
      null
    else
      builtins.head availableFallbacks;

  defaultPackages = lib.concatMapAttrs (
    appName: _appSpec:
    let
      namespace = preferredNamespaceFor appName;
    in
    if namespace == null then
      { }
    else
      {
        ${appName} = namespacedPackages.${namespace}.${appName};
      }
  ) appCatalog;

  namespacedApps = lib.mapAttrs (_namespace: pkgsByName: lib.mapAttrs (_name: mkApp) pkgsByName) namespacedPackages;
  defaultApps = lib.mapAttrs (_name: mkApp) defaultPackages;
in
{
  packages = defaultPackages;
  apps = defaultApps;
  packageVariants = namespacedPackages;
  appVariants = namespacedApps;
}
