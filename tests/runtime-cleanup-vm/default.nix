{
  pkgs,
  overlayfsLib,
}:
if !pkgs.stdenv.hostPlatform.isx86_64 then
  pkgs.runCommand "runtime-cleanup-vm-skipped" { } ''
    touch "$out"
  ''
else
  let
    basePackage =
      pkgs.runCommand "runtime-cleanup-vm-base"
        {
          pname = "runtime-cleanup-vm-base";
          version = "1.0.0";
        }
        ''
          mkdir -p "$out"
          touch "$out/probe"
        '';

    termRespawn = pkgs.writeShellScript "runtime-cleanup-vm-term-respawn" ''
      printf '%s\n' "$$" > "$NIX_OVERLAYFS_TEST_ROOT_PID"
      trap '
        ${pkgs.coreutils}/bin/sleep 30 &
        printf "%s\\n" "$!" > "$NIX_OVERLAYFS_TEST_REPLACEMENT_PID"
        exit 0
      ' TERM
      while :; do :; done
    '';

    stubborn = pkgs.writeShellScript "runtime-cleanup-vm-stubborn" ''
      printf '%s\n' "$$" > "$NIX_OVERLAYFS_TEST_STUBBORN_PID"
      trap "" TERM
      while :; do ${pkgs.coreutils}/bin/sleep 1; done
    '';

    launchProbe = pkgs.writeShellScript "runtime-cleanup-vm-launch" ''
      ${pkgs.util-linux}/bin/setsid ${termRespawn} &
      ${pkgs.util-linux}/bin/setsid ${stubborn} &
      while [ ! -s "$NIX_OVERLAYFS_TEST_ROOT_PID" ] \
        || [ ! -s "$NIX_OVERLAYFS_TEST_STUBBORN_PID" ]; do
        ${pkgs.coreutils}/bin/sleep 0.01
      done
    '';

    package = overlayfsLib.mkOverlayfsPackage {
      inherit basePackage;
      executableName = "runtime-cleanup-vm";
      executablePath = "/probe";
      launchProgram = launchProbe;
      hostIntegration = false;
      stateMode = "ephemeral";
      processTerminationTimeout = 1;
      extraPostLaunchCommands = ''
        printf '%s\n' post-launch >> "$NIX_OVERLAYFS_TEST_POST_LAUNCH"
      '';
    };
  in
  pkgs.testers.nixosTest {
    name = "runtime-cleanup-vm";

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
      machine.succeed("install -d -m 0700 -o alice -g users /run/user/1000")

      for mode in ["direct", "required"]:
          prefix = f"/tmp/runtime-cleanup-{mode}"
          machine.succeed(
              "su - alice -c '"
              f"HOME=/home/alice XDG_RUNTIME_DIR=/run/user/1000 "
              f"NIX_OVERLAYFS_NAMESPACE_MODE={mode} "
              f"NIX_OVERLAYFS_TEST_ROOT_PID={prefix}.root "
              f"NIX_OVERLAYFS_TEST_REPLACEMENT_PID={prefix}.replacement "
              f"NIX_OVERLAYFS_TEST_STUBBORN_PID={prefix}.stubborn "
              f"NIX_OVERLAYFS_TEST_POST_LAUNCH={prefix}.post "
              "${package}/bin/runtime-cleanup-vm' "
              f"> {prefix}.log 2>&1"
          )
          machine.succeed(f"grep -Fx post-launch {prefix}.post")
          machine.succeed(f"test $(wc -l < {prefix}.post) -eq 1")
          machine.succeed(f"grep -F 'terminating remaining processes' {prefix}.log")
          machine.succeed(f"test -s {prefix}.replacement")
          for suffix in ["root", "replacement", "stubborn"]:
              machine.succeed(f"! kill -0 $(cat {prefix}.{suffix}) 2>/dev/null")
          machine.succeed("test ! -e /run/user/1000/nix-overlayfs")
          machine.succeed("! findmnt -rn -t fuse.fuse-overlayfs")
    '';
  }
