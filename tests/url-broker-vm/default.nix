{
  pkgs,
  overlayfsLib,
}:
let
  inherit (pkgs) lib;
in
if !pkgs.stdenv.hostPlatform.isx86_64 then
  pkgs.runCommand "url-broker-vm-skipped" { } ''
    touch "$out"
  ''
else
  let
    modules = pkgs.nix-overlayfs.moduleScopes.nativeModules;

    winProbe = pkgs.pkgsCross.mingwW64.stdenv.mkDerivation {
      pname = "url-broker-win-probe";
      version = "1.0.0";

      dontUnpack = true;

      buildPhase = ''
        cat > url-probe.c <<'EOF'
        #include <windows.h>
        #include <shellapi.h>
        #include <stdlib.h>
        #include <wchar.h>

        int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous, LPWSTR command_line, int show_command) {
          int argc = 0;
          LPWSTR *argv = CommandLineToArgvW(GetCommandLineW(), &argc);
        if (argc > 1) {
            HANDLE file = CreateFileW(
              L"Z:\\tmp\\nix-overlayfs-return-url",
              FILE_APPEND_DATA,
              FILE_SHARE_READ | FILE_SHARE_WRITE,
              NULL,
              OPEN_ALWAYS,
              FILE_ATTRIBUTE_NORMAL,
              NULL
            );
            if (file == INVALID_HANDLE_VALUE) return 2;

            DWORD bytes = 0;
            char utf8[4096];
            int length = WideCharToMultiByte(CP_UTF8, 0, argv[1], -1, utf8, sizeof(utf8), NULL, NULL);
            if (length <= 0) return 3;
            WriteFile(file, utf8, (DWORD)(length - 1), &bytes, NULL);
            WriteFile(file, "\n", 1, &bytes, NULL);
            CloseHandle(file);
            if (wcsstr(argv[1], L"cold-start") != NULL) {
              HANDLE cold_started = CreateFileW(
                L"Z:\\tmp\\nix-overlayfs-cold-started",
                GENERIC_WRITE,
                0,
                NULL,
                CREATE_ALWAYS,
                FILE_ATTRIBUTE_NORMAL,
                NULL
              );
              if (cold_started != INVALID_HANDLE_VALUE) CloseHandle(cold_started);
              Sleep(20000);
            }
            return 0;
          }

          HANDLE started = CreateFileW(
            L"Z:\\tmp\\nix-overlayfs-probe-started",
            GENERIC_WRITE,
            0,
            NULL,
            CREATE_ALWAYS,
            FILE_ATTRIBUTE_NORMAL,
            NULL
          );
          if (started != INVALID_HANDLE_VALUE) CloseHandle(started);

          ShellExecuteW(
            NULL,
            L"open",
            L"https://example.invalid/login?state=from-wine",
            NULL,
            NULL,
            SW_SHOWNORMAL
          );
          _wsystem(L"cmd /c start https://example.invalid/login?state=from-cmd-start");
          STARTUPINFOW startup_info = {0};
          PROCESS_INFORMATION process_info = {0};
          WCHAR command[] = L"cmd /c start https://example.invalid/login?client_id=probe^&response_type=code^&scope=openid+profile^&redirect_uri=https%3a%2f%2fexample.invalid%2fcomplete^&state=from-cmd-start-long";
          startup_info.cb = sizeof(startup_info);
          if (CreateProcessW(NULL, command, NULL, NULL, FALSE, 0, NULL, NULL, &startup_info, &process_info)) {
            WaitForSingleObject(process_info.hProcess, 10000);
            CloseHandle(process_info.hThread);
            CloseHandle(process_info.hProcess);
          }
          Sleep(20000);
          return 0;
        }
        EOF

        $CC -municode -mwindows -o url-probe.exe url-probe.c -lshell32
      '';

      installPhase = ''
        install -Dm755 url-probe.exe "$out/url-probe.exe"
      '';
    };

    basePackage = pkgs.stdenvNoCC.mkDerivation {
      pname = "url-broker-vm-base";
      version = "1.0.0";

      dontUnpack = true;

      installPhase = ''
        install -Dm755 "${winProbe}/url-probe.exe" "$out/drive_c/url-probe/url-probe.exe"
      '';
    };

    probePackage = overlayfsLib.composeWindowsLayers {
      inherit (modules) runtime;
      baseLayer = {
        inherit basePackage;
        overlayDependencies = [ ];
        runtimeEnvVars = { };
      };
      packageName = "url-broker-vm";
      executableName = "url-broker-vm";
      executablePath = "/drive_c/url-probe/url-probe.exe";
      workingDirectory = "/drive_c/url-probe";
      urlSchemes = [ "probe" ];
    };

    fakeBrowser = pkgs.writeShellScriptBin "nix-overlayfs-vm-browser" ''
      set -eu

      target="$1"
      printf '%s\n' "$target" >> /tmp/nix-overlayfs-browser-url

      for _ in $(seq 1 100); do
        if xdg-mime query default x-scheme-handler/probe 2>/dev/null | grep -q '^url-broker-vm-nix-overlayfs-url-handler.desktop$'; then
          break
        fi
        sleep 0.1
      done

      xdg-open 'probe://browser-return?code=ok&state=from-browser'
    '';
  in
  pkgs.testers.nixosTest {
    name = "url-broker-vm";

    nodes.machine =
      { pkgs, ... }:
      {
        users.users.alice = {
          isNormalUser = true;
          home = "/home/alice";
        };

        boot.kernel.sysctl."kernel.unprivileged_userns_clone" = 1;

        environment.systemPackages = [
          fakeBrowser
          pkgs.xdg-utils
        ];
      };

    testScript = ''
      machine.start()
      machine.wait_for_unit("multi-user.target")

      machine.succeed("install -d -m 0755 -o alice -g users /home/alice/.local /home/alice/.local/share /home/alice/.local/share/applications /home/alice/.config /home/alice/.cache")
      machine.succeed(
          "cat > /home/alice/.local/share/applications/nix-overlayfs-vm-browser.desktop <<'EOF'\n"
          "[Desktop Entry]\n"
          "Type=Application\n"
          "Name=nix-overlayfs VM Browser\n"
          "Exec=${fakeBrowser}/bin/nix-overlayfs-vm-browser %u\n"
          "MimeType=x-scheme-handler/http;x-scheme-handler/https;\n"
          "NoDisplay=true\n"
          "EOF\n"
          "chown alice:users /home/alice/.local/share/applications/nix-overlayfs-vm-browser.desktop"
      )
      machine.succeed("su - alice -c 'export XDG_DATA_HOME=$HOME/.local/share XDG_CONFIG_HOME=$HOME/.config XDG_CACHE_HOME=$HOME/.cache; update-desktop-database $XDG_DATA_HOME/applications; xdg-mime default nix-overlayfs-vm-browser.desktop x-scheme-handler/http; xdg-mime default nix-overlayfs-vm-browser.desktop x-scheme-handler/https'")

      machine.succeed("rm -f /tmp/nix-overlayfs-return-url /tmp/nix-overlayfs-cold-started /tmp/nix-overlayfs-cold-start.log /tmp/nix-overlayfs-cold-session.pid /tmp/nix-overlayfs-cold-overlay-root")
      machine.succeed("su - alice -c 'export XDG_DATA_HOME=$HOME/.local/share XDG_CONFIG_HOME=$HOME/.config XDG_CACHE_HOME=$HOME/.cache; nohup ${probePackage}/bin/url-broker-vm --nix-overlayfs-open-url probe://cold-start?state=initial > /tmp/nix-overlayfs-cold-start.log 2>&1 &'")
      machine.succeed(
          "timeout 60 bash -c 'until [ -e /tmp/nix-overlayfs-cold-started ]; do sleep 0.25; done' || "
          "{ echo COLD_START_LOG; cat /tmp/nix-overlayfs-cold-start.log || true; "
          "echo STATE; find /home/alice/.local/share/url-broker-vm/.nix-overlayfs -maxdepth 2 -type f -print -exec sh -c 'echo --- $1; cat $1 || true' sh {} \\; 2>/dev/null || true; false; }"
      )
      machine.succeed("test -s /home/alice/.local/share/url-broker-vm/.nix-overlayfs/session.pid")
      machine.succeed("test -s /home/alice/.local/share/url-broker-vm/.nix-overlayfs/overlay-root")
      machine.succeed("test -s /home/alice/.local/share/url-broker-vm/.nix-overlayfs/session-env")
      machine.succeed("grep -F 'WINEPREFIX=' /home/alice/.local/share/url-broker-vm/.nix-overlayfs/session-env")
      machine.succeed("cp /home/alice/.local/share/url-broker-vm/.nix-overlayfs/session.pid /tmp/nix-overlayfs-cold-session.pid")
      machine.succeed("cp /home/alice/.local/share/url-broker-vm/.nix-overlayfs/overlay-root /tmp/nix-overlayfs-cold-overlay-root")
      machine.succeed("su - alice -c 'export XDG_DATA_HOME=$HOME/.local/share XDG_CONFIG_HOME=$HOME/.config XDG_CACHE_HOME=$HOME/.cache; xdg-open probe://cold-second?state=same-session'")
      machine.succeed(
          "timeout 60 bash -c \"until grep -Fxq 'probe://cold-second?state=same-session' /tmp/nix-overlayfs-return-url 2>/dev/null; do sleep 0.25; done\" || "
          "{ echo COLD_START_LOG; cat /tmp/nix-overlayfs-cold-start.log || true; "
          "echo RETURN_URL; cat /tmp/nix-overlayfs-return-url || true; "
          "echo STATE; find /home/alice/.local/share/url-broker-vm/.nix-overlayfs -maxdepth 2 -type f -print -exec sh -c 'echo --- $1; cat $1 || true' sh {} \\; 2>/dev/null || true; false; }"
      )
      machine.succeed("cmp /tmp/nix-overlayfs-cold-session.pid /home/alice/.local/share/url-broker-vm/.nix-overlayfs/session.pid")
      machine.succeed("cmp /tmp/nix-overlayfs-cold-overlay-root /home/alice/.local/share/url-broker-vm/.nix-overlayfs/overlay-root")
      machine.succeed(
          "timeout 60 bash -c 'pid=$(cat /tmp/nix-overlayfs-cold-session.pid); while kill -0 \"$pid\" 2>/dev/null; do sleep 0.25; done' || "
          "{ echo COLD_START_LOG; cat /tmp/nix-overlayfs-cold-start.log || true; false; }"
      )

      machine.succeed("rm -f /tmp/nix-overlayfs-browser-url /tmp/nix-overlayfs-return-url /tmp/nix-overlayfs-probe-started /tmp/nix-overlayfs-url-broker.log")
      machine.succeed("su - alice -c 'export XDG_DATA_HOME=$HOME/.local/share XDG_CONFIG_HOME=$HOME/.config XDG_CACHE_HOME=$HOME/.cache; nohup ${probePackage}/bin/url-broker-vm > /tmp/nix-overlayfs-url-broker.log 2>&1 &'")

      machine.succeed(
          "timeout 60 bash -c 'until [ -e /tmp/nix-overlayfs-probe-started ]; do sleep 0.25; done' || "
          "{ echo PROBE_LOG; cat /tmp/nix-overlayfs-url-broker.log || true; "
          "echo MIME_DEFAULTS; su - alice -c 'XDG_DATA_HOME=$HOME/.local/share XDG_CONFIG_HOME=$HOME/.config xdg-mime query default x-scheme-handler/https || true'; false; }"
      )
      machine.succeed("awk 'index($0, \"WineBrowser\") && substr($0, 1, 1) == \"[\" { line = $0; if (gsub(/\\\\\\\\/, \"\", line) == 2) found = 1 } END { exit !found }' /home/alice/.local/share/url-broker-vm/user.reg")
      machine.succeed("awk 'index($0, \"WineBrowser\") && substr($0, 1, 1) == \"[\" { count++ } END { exit count != 1 }' /home/alice/.local/share/url-broker-vm/user.reg")
      machine.succeed("awk 'index($0, \"Classes\") && index($0, \"probe]\") && substr($0, 1, 1) == \"[\" { line = $0; if (gsub(/\\\\\\\\/, \"\", line) == 2) found = 1 } END { exit !found }' /home/alice/.local/share/url-broker-vm/user.reg")
      machine.succeed("awk 'index($0, \"Classes\") && index($0, \"probe]\") && substr($0, 1, 1) == \"[\" { count++ } END { exit count != 1 }' /home/alice/.local/share/url-broker-vm/user.reg")
      machine.succeed("awk 'substr($0, 1, 1) == \"[\" && index($0, \"Classes\") && index($0, \"probe\") && index($0, \"shell\") && index($0, \"open\") && index($0, \"command\") { found = 1 } END { exit !found }' /home/alice/.local/share/url-broker-vm/user.reg")
      machine.succeed("! grep -F '[SoftwareClassesprobe]' /home/alice/.local/share/url-broker-vm/user.reg")
      machine.succeed(
          "timeout 60 bash -c 'until [ -e /tmp/nix-overlayfs-browser-url ]; do sleep 0.25; done' || "
          "{ echo PROBE_LOG; cat /tmp/nix-overlayfs-url-broker.log || true; "
          "echo HOST_REQUESTS; find /home/alice/.local/share/url-broker-vm/.nix-overlayfs -maxdepth 3 -type f -print -exec sh -c 'echo --- $1; cat $1 || true' sh {} \\; 2>/dev/null || true; false; }"
      )
      machine.succeed(
          "timeout 60 bash -c \"until grep -Fxq 'https://example.invalid/login?state=from-wine' /tmp/nix-overlayfs-browser-url 2>/dev/null && grep -Fxq 'https://example.invalid/login?state=from-cmd-start' /tmp/nix-overlayfs-browser-url 2>/dev/null && grep -Fxq 'https://example.invalid/login?client_id=probe&response_type=code&scope=openid+profile&redirect_uri=https%3a%2f%2fexample.invalid%2fcomplete&state=from-cmd-start-long' /tmp/nix-overlayfs-browser-url 2>/dev/null; do sleep 0.25; done\" || "
          "{ echo PROBE_LOG; cat /tmp/nix-overlayfs-url-broker.log || true; "
          "echo BROWSER_URL; cat /tmp/nix-overlayfs-browser-url || true; "
          "echo STATE; find /home/alice/.local/share/url-broker-vm/.nix-overlayfs -maxdepth 3 -type f -print -exec sh -c 'echo --- $1; cat $1 || true' sh {} \\; 2>/dev/null || true; false; }"
      )
      machine.succeed(
          "timeout 60 bash -c 'until [ -e /tmp/nix-overlayfs-return-url ]; do sleep 0.25; done' || "
          "{ echo PROBE_LOG; cat /tmp/nix-overlayfs-url-broker.log || true; "
          "echo BROWSER_URL; cat /tmp/nix-overlayfs-browser-url || true; "
          "echo STATE; find /home/alice/.local/share/url-broker-vm/.nix-overlayfs -maxdepth 3 -type f -print -exec sh -c 'echo --- $1; cat $1 || true' sh {} \\; 2>/dev/null || true; false; }"
      )

      machine.succeed("grep -Fx 'https://example.invalid/login?state=from-wine' /tmp/nix-overlayfs-browser-url")
      machine.succeed("grep -Fx 'https://example.invalid/login?state=from-cmd-start' /tmp/nix-overlayfs-browser-url")
      machine.succeed("grep -Fx 'https://example.invalid/login?client_id=probe&response_type=code&scope=openid+profile&redirect_uri=https%3a%2f%2fexample.invalid%2fcomplete&state=from-cmd-start-long' /tmp/nix-overlayfs-browser-url")
      machine.succeed("grep -Fx 'probe://browser-return?code=ok&state=from-browser' /tmp/nix-overlayfs-return-url")
    '';
  }
