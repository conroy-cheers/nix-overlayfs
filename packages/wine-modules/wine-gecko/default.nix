{
  lib,
  pkgs,
  runtime,
  overlayfsLib,
}:
let
  wineSources = import "${pkgs.path}/pkgs/applications/emulators/wine/sources.nix" {
    inherit pkgs;
  };
  sourceSet =
    if runtime.version == wineSources.stable.version then
      wineSources.stable
    else
      wineSources.unstable;
  geckoVersion = builtins.head (builtins.match "wine-gecko-([0-9.]+)-.*[.]msi" sourceSet.gecko64.name);
  installers =
    if runtime.windowsArch == "win32" then
      [ sourceSet.gecko32 ]
    else
      [
        sourceSet.gecko64
        sourceSet.gecko32
      ];
  registryCommands =
    if runtime.windowsArch == "win32" then
      [
        {
          subdir = "system32";
          regFlag = "";
        }
      ]
    else
      [
        {
          subdir = "system32";
          regFlag = "/reg:64";
        }
        {
          subdir = "syswow64";
          regFlag = "/reg:32";
        }
      ];
in
overlayfsLib.mkWindowsPackage {
  inherit runtime;
  pname = "wine-gecko";
  version = geckoVersion;
  src = sourceSet.gecko64;
  packageName = "wine-gecko";
  unshareInstall =
    { session, ... }:
    ''
      ${lib.concatMapStringsSep "\n" (
        msi: ''${session.commands.wine} msiexec /i "${msi}" /qn || true''
      ) installers}

      ${lib.concatMapStringsSep "\n" (
        view: ''
          ${pkgs.coreutils}/bin/timeout --foreground 30s ${session.commands.wine} reg add 'HKLM\Software\Wine\MSHTML\${geckoVersion}' \
            /v GeckoPath /t REG_SZ /d 'C:\windows\${view.subdir}\gecko\${geckoVersion}\wine_gecko\' /f ${view.regFlag} || true
        ''
      ) registryCommands}

      ${pkgs.coreutils}/bin/timeout --foreground 60s ${session.commands.wineserver} --wait || {
        echo "warning: wineserver did not exit within 60s after Wine Gecko install; killing remaining Wine processes" >&2
        ${session.commands.wineserver} -k || true
      }
    '';

  passthru = {
    inherit geckoVersion installers;
  };
}
