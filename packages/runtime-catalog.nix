{
  lib,
  pkgs,
  nix-gaming,
  nix-gaming-legacy,
  overlayfsLib,
  toolchains,
}:
let
  isAarch64 = pkgs.stdenv.hostPlatform.isAarch64;
  mkRuntime = pkgs.callPackage ./mk-runtime.nix { };
  makeModules =
    runtime:
    pkgs.callPackage ./wine-modules {
      inherit overlayfsLib runtime;
    };

  nativeRuntime = args: mkRuntime args;

  withModules = runtime: makeModules runtime;

  nativeWin32Modules =
    lib.optionalAttrs (!isAarch64) {
      runtime = nativeRuntime {
        wine = pkgs.winePackages.stableFull;
        windowsArch = "win32";
      };
    };

  nativeWow64Modules =
    lib.optionalAttrs (!isAarch64) {
      runtime = nativeRuntime {
        wine = pkgs.wineWow64Packages.unstableFull;
        windowsArch = "wow64";
      };
    };

  geWin32Modules =
    lib.optionalAttrs (!isAarch64) {
      runtime = nativeRuntime {
        wine = nix-gaming-legacy.wine-ge;
        windowsArch = "win32";
        id = "ge-win32";
      };
    };

  tkgWow64Modules =
    lib.optionalAttrs (!isAarch64) {
      runtime = nativeRuntime {
        wine = nix-gaming.wine-tkg;
        windowsArch = "wow64";
        id = "tkg-wow64";
      };
    };

  x64FexRuntime =
    if isAarch64 then
      nativeRuntime {
        windowsArch = "wow64";
        id = "native-arm64ec-wow64";
        wine = toolchains.nativeArm64ecWineWithFex;
        backend = "wine-arm64ec-fex";
        preferredInstallerArchitecture = "x64";
        capabilities = {
          supportsWin32WoW = true;
          usesFexWoa = true;
        };
        extraPreCommands = ''
          mkdir -p \
            "$WINEPREFIX/drive_c/windows/system32" \
            "$WINEPREFIX/drive_c/windows/syswow64" \
            "$WINEPREFIX/drive_c/windows/sysarm32"

          ln -sfn \
            ${toolchains.nativeArm64ecWineWithFex}/lib/wine/aarch64-windows/libarm64ecfex.dll \
            "$WINEPREFIX/drive_c/windows/system32/xtajit64.dll"
          ln -sfn \
            ${toolchains.nativeArm64ecWineWithFex}/lib/wine/aarch64-windows/libarm64ecfex.dll \
            "$WINEPREFIX/drive_c/windows/syswow64/xtajit64.dll"
          ln -sfn \
            ${toolchains.nativeArm64ecWineWithFex}/lib/wine/aarch64-windows/libarm64ecfex.dll \
            "$WINEPREFIX/drive_c/windows/sysarm32/xtajit64.dll"

          ln -sfn \
            ${toolchains.nativeArm64ecWineWithFex}/lib/wine/aarch64-windows/libwow64fex.dll \
            "$WINEPREFIX/drive_c/windows/system32/xtajit.dll"
          ln -sfn \
            ${toolchains.nativeArm64ecWineWithFex}/lib/wine/aarch64-windows/libwow64fex.dll \
            "$WINEPREFIX/drive_c/windows/syswow64/xtajit.dll"
          ln -sfn \
            ${toolchains.nativeArm64ecWineWithFex}/lib/wine/aarch64-windows/libwow64fex.dll \
            "$WINEPREFIX/drive_c/windows/sysarm32/xtajit.dll"
        '';
        extraPostCommands = "";
      }
    else
      null;

  nativeArm64Runtime =
    if isAarch64 then
      nativeRuntime {
        wine = toolchains.nativeArm64ecWine;
        windowsArch = "wow64";
        id = "native-arm64";
        preferredInstallerArchitecture = "arm64";
        capabilities = {
          supportsWin32WoW = false;
          usesFexWoa = false;
        };
      }
    else
      null;

  x64FexModules =
    if isAarch64 then
      withModules (
        x64FexRuntime
        // {
          mkPrefixInitCommands = session: ''
            ${session.commands.wine} reg add 'HKLM\Software\Microsoft\Wow64' /v amd64 /d libarm64ecfex.dll /f
            ${session.commands.wine} reg add 'HKLM\Software\Microsoft\Wow64\amd64' /ve /d libarm64ecfex.dll /f
            ${session.commands.wine} reg add 'HKLM\Software\Microsoft\Wow64' /v x86 /d libwow64fex.dll /f
            ${session.commands.wine} reg add 'HKLM\Software\Microsoft\Wow64\x86' /ve /d libwow64fex.dll /f
            ${session.commands.wine} reg add 'HKLM\System\CurrentControlSet\Control\Session Manager\KnownDLLs' /v xtajit /d libwow64fex.dll /f
            ${session.commands.wine} reg add 'HKLM\System\CurrentControlSet\Control\Session Manager\KnownDLLs' /v xtajit64 /d libarm64ecfex.dll /f
            ${session.commands.wineserver} --wait
          '';
        }
      )
    else
      null;

  nativeModules =
    if isAarch64 then
      withModules nativeArm64Runtime
    else
      withModules nativeWow64Modules.runtime;
in
lib.optionalAttrs (!isAarch64) {
  nativeWin32Modules = withModules nativeWin32Modules.runtime;
  nativeWow64Modules = withModules nativeWow64Modules.runtime;
  geWin32Modules = withModules geWin32Modules.runtime;
  tkgWow64Modules = withModules tkgWow64Modules.runtime;
  inherit nativeModules;
}
// lib.optionalAttrs isAarch64 {
  inherit nativeModules x64FexModules;
}
