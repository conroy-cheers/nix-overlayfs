{
  pkgs,
  overlayfsLib,
}:
if !pkgs.stdenv.hostPlatform.isx86_64 then
  pkgs.runCommand "namespace-modes-vm-skipped" { } ''
    touch "$out"
  ''
else
  let
    basePackage = pkgs.stdenvNoCC.mkDerivation {
      pname = "namespace-modes-vm-base";
      version = "1.0.0";
      dontUnpack = true;
      installPhase = ''
        mkdir -p "$out"
        touch "$out/probe"
      '';
    };

    launchProbe = pkgs.writeShellScript "namespace-modes-vm-probe" ''
      set -eu
      test -f "$1"
      {
        printf 'direct=%s\n' "''${NIX_OVERLAYFS_DIRECT_MODE:-0}"
        printf 'mount_namespace=%s\n' "$(readlink /proc/self/ns/mnt)"
        printf 'uid=%s\n' "$(id -u)"
      } > "$NIX_OVERLAYFS_TEST_RESULT"
    '';

    probePackage = overlayfsLib.mkOverlayfsPackage {
      inherit basePackage;
      executableName = "namespace-modes-vm";
      executablePath = "/probe";
      launchProgram = launchProbe;
    };
  in
  pkgs.testers.nixosTest {
    name = "namespace-modes-vm";

    nodes.machine = {
      users.users.alice = {
        isNormalUser = true;
        home = "/home/alice";
      };
      boot.kernel.sysctl."kernel.unprivileged_userns_clone" = 1;
    };

    testScript = ''
      machine.start()
      machine.wait_for_unit("multi-user.target")
      machine.succeed("install -d -m 0755 -o alice -g users /home/alice/.cache /home/alice/.local /home/alice/.local/share")
      init_namespace = machine.succeed("readlink /proc/1/ns/mnt").strip()

      def run_mode(mode):
          machine.succeed(
              f"su - alice -c 'NIX_OVERLAYFS_NAMESPACE_MODE={mode} "
              f"NIX_OVERLAYFS_TEST_RESULT=/tmp/{mode}.result "
              f"${probePackage}/bin/namespace-modes-vm > /tmp/{mode}.log 2>&1'"
          )
          result = machine.succeed(f"cat /tmp/{mode}.result")
          namespace = machine.succeed(
              f"sed -n 's/^mount_namespace=//p' /tmp/{mode}.result"
          ).strip()
          machine.succeed(f"grep -Fx 'uid=1000' /tmp/{mode}.result")
          machine.succeed(f"! grep -F 'unknown argument ignored' /tmp/{mode}.log")
          return result, namespace

      required_result, required_namespace = run_mode("required")
      assert "direct=0" in required_result
      assert required_namespace != init_namespace

      auto_result, auto_namespace = run_mode("auto")
      assert "direct=0" in auto_result
      assert auto_namespace != init_namespace
      machine.succeed("! grep -F 'using direct FUSE mode' /tmp/auto.log")

      direct_result, direct_namespace = run_mode("direct")
      assert "direct=1" in direct_result
      assert direct_namespace == init_namespace
      machine.succeed("test -d /home/alice/.local/share/applications")
      machine.succeed("! grep -F '/applications' /tmp/required.log /tmp/auto.log /tmp/direct.log")

      machine.fail(
          "su - alice -c 'NIX_OVERLAYFS_NAMESPACE_MODE=invalid "
          "${probePackage}/bin/namespace-modes-vm > /tmp/invalid.log 2>&1'"
      )
      machine.succeed("grep -F 'must be one of: auto, required, direct' /tmp/invalid.log")

      machine.succeed("! findmnt -rn -t fuse.fuse-overlayfs | grep -F '/home/alice/.cache/nix-overlayfs/tmp/'")
      machine.succeed("test -z \"$(find /home/alice/.cache/nix-overlayfs/tmp -mindepth 1 -maxdepth 1 -type d -print -quit)\"")
    '';
  }
