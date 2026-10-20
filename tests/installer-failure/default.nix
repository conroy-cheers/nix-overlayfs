{ pkgs, overlayfsLib }:
let
  failure = pkgs.writeShellScript "failing-windows-installer" "exit 42";
  runtime = {
    version = "test";
    toolsPackage = pkgs.emptyDirectory;
    windowsArch = "win32";
    programFilesPath = "/drive_c/Program Files";
    baseEnvLayer = pkgs.emptyDirectory;
    autohotkeyLayer = null;
    mkSession = _: {
      env = { };
      preCommands = "";
      postCommands = "touch cleanup-ran";
      buildInputs = [ ];
      commands = {
        wine = "${failure}";
        wineserver = "${pkgs.coreutils}/bin/true";
      };
    };
  };
  package = overlayfsLib.mkWindowsPackage {
    inherit runtime;
    pname = "installer-failure";
    version = "1";
    packageName = "installer-failure";
    postInstall = "touch post-install-ran";
    src = pkgs.writeText "mock-installer.exe" "";
  };
in
pkgs.runCommand "windows-installer-failure-status" { } ''
  set +e
  ${package.basePackage.buildPhaseUnshareScript}
  status=$?
  set -e
  test "$status" = 42
  test -f cleanup-ran
  test ! -e post-install-ran
  touch "$out"
''
