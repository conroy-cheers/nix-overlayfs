{
  lib,
  symlinkJoin,
}:
{
  wine,
  windowsArch ? "wow64",
  id ? "native-${windowsArch}",
  backend ? "wine-native",
  preferredInstallerArchitecture ? if windowsArch == "win32" then "x86" else "x64",
  capabilities ? { },
  extraEnv ? { },
  extraPreCommands ? "",
  extraPostCommands ? "",
  extraCommands ? { },
}:
let
  runtimeVersion = if (wine ? version) then wine.version else lib.getVersion wine;

  toolsPackage = symlinkJoin {
    pname = "${if (wine ? pname) then wine.pname else "wine"}-${windowsArch}-tools";
    version = runtimeVersion;
    paths = [ wine ];
    meta = (wine.meta or { }) // {
      mainProgram = "wine";
    };
  };

  commands =
    let
      wineCommand = "${toolsPackage}/bin/wine";
    in
    {
      wine = wineCommand;
      wine64 = if windowsArch == "win32" then null else wineCommand;
      wineserver = "${toolsPackage}/bin/wineserver";
      wineboot = "${toolsPackage}/bin/wineboot";
      winecfg = "${toolsPackage}/bin/winecfg";
    }
    // extraCommands;
in
rec {
  inherit id toolsPackage windowsArch preferredInstallerArchitecture backend;
  version = runtimeVersion;
  programFiles32Path = "/drive_c/Program Files" + (if windowsArch == "win32" then "" else " (x86)");
  programFilesPath = "/drive_c/Program Files";
  baseEnvLayer = null;
  autohotkeyLayer = null;
  capabilities = {
    canRunWin64 = windowsArch != "win32";
    requires4kPages = false;
    requiresGuestRootfs = false;
  } // capabilities;

  mkSession =
    {
      phase ? "launch",
      sessionRoot,
      overlayRoot,
      homeDir,
    }:
    {
      buildInputs = [ toolsPackage ];
      env = {
        HOME = ''"${homeDir}"'';
        WINEPREFIX = ''"${overlayRoot}"'';
        WINEARCH = lib.escapeShellArg windowsArch;
        XDG_RUNTIME_DIR = ''"${sessionRoot}/xdg-runtime"'';
      } // extraEnv;
      preCommands = ''
        mkdir -p "${sessionRoot}" "${sessionRoot}/xdg-runtime"
        chmod 700 "${sessionRoot}/xdg-runtime"
      '' + extraPreCommands;
      postCommands = extraPostCommands;
      inherit commands;
    };
}
