{
  pkgs,
  overlayfsLib,
}:
if !pkgs.stdenv.hostPlatform.isx86_64 then
  pkgs.runCommand "headless-runtime-vm-skipped" { } ''
    touch "$out"
  ''
else
  let
    modules = pkgs.nix-overlayfs.moduleScopes.nativeWin32HeadlessModules;
    probeSource = pkgs.writeText "headless-runtime-probe.c" ''
      #include <stdio.h>
      int main(void) { puts("headless-runtime-ok"); return 0; }
    '';

    windowsExecutable = pkgs.pkgsCross.mingw32.stdenv.mkDerivation {
      pname = "headless-runtime-probe-windows";
      version = "1.0.0";
      dontUnpack = true;
      buildPhase = ''
        $CC -Os -s -o headless-runtime.exe ${probeSource}
      '';
      installPhase = ''
        mkdir -p "$out/bin"
        cp headless-runtime.exe "$out/bin/"
      '';
    };

    basePackage = pkgs.stdenvNoCC.mkDerivation {
      pname = "headless-runtime-vm-base";
      version = "1.0.0";
      dontUnpack = true;
      installPhase = ''
        mkdir -p "$out/bin"
        cp ${windowsExecutable}/bin/headless-runtime.exe "$out/bin/"
      '';
    };

    package = overlayfsLib.composeWindowsLayers {
      inherit (modules) runtime;
      packageName = "headless-runtime-vm";
      baseLayer = {
        inherit basePackage;
        overlayDependencies = [ ];
        runtimeEnvVars = { };
      };
      executableName = "headless-runtime-vm";
      executablePath = "bin/headless-runtime.exe";
      hostIntegration = false;
      managedRuntime = "disabled";
      namespaceMode = "direct";
      stateMode = "ephemeral";
    };
  in
  pkgs.testers.nixosTest {
    name = "headless-runtime-vm";

    nodes.machine = {
      users.users.alice = {
        isNormalUser = true;
        home = "/home/alice";
      };
      environment.systemPackages = [ pkgs.xorg-server ];
    };

    testScript = ''
      machine.start()
      machine.wait_for_unit("multi-user.target")
      machine.succeed("install -d -m 0700 -o alice -g users /run/user/1000")
      machine.succeed("Xvfb :99 -screen 0 640x480x24 -ac > /tmp/xvfb.log 2>&1 &")
      machine.wait_until_succeeds("test -S /tmp/.X11-unix/X99")

      machine.succeed(
          "su - alice -c 'HOME=/home/alice USER=alice DISPLAY=:99 "
          "XDG_RUNTIME_DIR=/run/user/1000 "
          "NIX_OVERLAYFS_WINESERVER_SHUTDOWN_TIMEOUT=5s "
          "timeout 20s ${package}/bin/headless-runtime-vm' "
          "> /tmp/headless-runtime.log 2>&1"
      )
      machine.succeed("grep -F headless-runtime-ok /tmp/headless-runtime.log")
      machine.succeed("! grep -Eiq 'wine-mono|wine-gecko|could not find' /tmp/headless-runtime.log")
      machine.succeed("test ! -e /home/alice/.local")
      machine.succeed("test ! -e /run/user/1000/nix-overlayfs")
      machine.succeed("! findmnt -rn -t fuse.fuse-overlayfs")
      machine.succeed("! pgrep -x wineserver")
    '';
  }
