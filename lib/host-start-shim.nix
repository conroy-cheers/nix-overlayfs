{ pkgs }:

let
  buildStartShim =
    crossPkgs:
    crossPkgs.stdenv.mkDerivation {
      pname = "nix-overlayfs-start-shim-${crossPkgs.stdenv.hostPlatform.parsed.cpu.name}";
      version = "1.0.0";

      dontUnpack = true;

      buildPhase = ''
        cat > start-shim.c <<'EOF'
    #define UNICODE
    #define _UNICODE
    #include <windows.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <wchar.h>

    static int is_option(const wchar_t *arg) {
      return arg && (arg[0] == L'/' || arg[0] == L'-');
    }

    static int option_takes_value(const wchar_t *arg) {
      return _wcsicmp(arg, L"/d") == 0 || _wcsicmp(arg, L"-d") == 0;
    }

    static wchar_t *unix_path_to_wine_path(const wchar_t *path) {
      size_t length = wcslen(path);
      size_t extra = (path[0] == L'/') ? 2 : 0;
      wchar_t *converted = (wchar_t *)calloc(length + extra + 1, sizeof(wchar_t));
      if (!converted) return NULL;

      wchar_t *cursor = converted;
      if (path[0] == L'/') {
        *cursor++ = L'Z';
        *cursor++ = L':';
      }

      while (*path) {
        *cursor++ = (*path == L'/') ? L'\\' : *path;
        path++;
      }
      *cursor = L'\0';
      return converted;
    }

    static int enqueue_host_open_request(const wchar_t *target) {
      DWORD env_length = GetEnvironmentVariableW(L"NIX_OVERLAYFS_HOST_OPEN_DIR_WIN", NULL, 0);
      const wchar_t *env_name = L"NIX_OVERLAYFS_HOST_OPEN_DIR_WIN";
      int env_is_windows_path = 1;
      if (env_length == 0) {
        env_length = GetEnvironmentVariableW(L"NIX_OVERLAYFS_HOST_OPEN_DIR", NULL, 0);
        env_name = L"NIX_OVERLAYFS_HOST_OPEN_DIR";
        env_is_windows_path = 0;
      }
      if (env_length == 0) return -1;

      wchar_t *request_dir = (wchar_t *)calloc(env_length + 1, sizeof(wchar_t));
      if (!request_dir) return 1;

      if (!GetEnvironmentVariableW(env_name, request_dir, env_length)) {
        free(request_dir);
        return -1;
      }

      wchar_t *request_dir_path = env_is_windows_path ? _wcsdup(request_dir) : unix_path_to_wine_path(request_dir);
      free(request_dir);
      if (!request_dir_path) return 1;

      DWORD pid = GetCurrentProcessId();
      DWORD tick = GetTickCount();
      size_t path_length = wcslen(request_dir_path) + 96;
      wchar_t *tmp_path = (wchar_t *)calloc(path_length, sizeof(wchar_t));
      wchar_t *final_path = (wchar_t *)calloc(path_length, sizeof(wchar_t));
      if (!tmp_path || !final_path) {
        free(request_dir_path);
        free(tmp_path);
        free(final_path);
        return 1;
      }

      swprintf(tmp_path, path_length, L"%ls\\request.%lu.%lu.tmp", request_dir_path, (unsigned long)pid, (unsigned long)tick);
      swprintf(final_path, path_length, L"%ls\\request.%lu.%lu", request_dir_path, (unsigned long)pid, (unsigned long)tick);
      free(request_dir_path);

      HANDLE file = CreateFileW(tmp_path, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
      if (file == INVALID_HANDLE_VALUE) {
        free(tmp_path);
        free(final_path);
        return 1;
      }

      int utf8_length = WideCharToMultiByte(CP_UTF8, 0, target, -1, NULL, 0, NULL, NULL);
      if (utf8_length <= 0) {
        CloseHandle(file);
        DeleteFileW(tmp_path);
        free(tmp_path);
        free(final_path);
        return 1;
      }

      char *utf8 = (char *)calloc((size_t)utf8_length + 1, sizeof(char));
      if (!utf8) {
        CloseHandle(file);
        DeleteFileW(tmp_path);
        free(tmp_path);
        free(final_path);
        return 1;
      }

      WideCharToMultiByte(CP_UTF8, 0, target, -1, utf8, utf8_length, NULL, NULL);
      DWORD written = 0;
      BOOL ok = WriteFile(file, utf8, (DWORD)(utf8_length - 1), &written, NULL);
      if (ok) ok = WriteFile(file, "\n", 1, &written, NULL);
      CloseHandle(file);
      free(utf8);

      if (!ok || !MoveFileExW(tmp_path, final_path, MOVEFILE_REPLACE_EXISTING)) {
        DeleteFileW(tmp_path);
        free(tmp_path);
        free(final_path);
        return 1;
      }

      free(tmp_path);
      free(final_path);
      return 0;
    }

    static size_t quoted_arg_length(const wchar_t *arg) {
      size_t length = 2;
      while (*arg) {
        if (*arg == L'"') length++;
        length++;
        arg++;
      }
      return length;
    }

    static wchar_t *append_quoted_arg(wchar_t *cursor, const wchar_t *arg) {
      *cursor++ = L'"';
      while (*arg) {
        if (*arg == L'"') *cursor++ = L'\\';
        *cursor++ = *arg++;
      }
      *cursor++ = L'"';
      return cursor;
    }

    static int run_exec(int argc, LPWSTR *argv, int first_arg) {
      size_t length = 1;
      for (int i = first_arg; i < argc; i++) {
        length += quoted_arg_length(argv[i]) + 1;
      }

      wchar_t *command_line = (wchar_t *)calloc(length, sizeof(wchar_t));
      if (!command_line) return 1;

      wchar_t *cursor = command_line;
      for (int i = first_arg; i < argc; i++) {
        if (i != first_arg) *cursor++ = L' ';
        cursor = append_quoted_arg(cursor, argv[i]);
      }
      *cursor = L'\0';

      STARTUPINFOW startup;
      PROCESS_INFORMATION process;
      ZeroMemory(&startup, sizeof(startup));
      ZeroMemory(&process, sizeof(process));
      startup.cb = sizeof(startup);

      BOOL created = CreateProcessW(NULL, command_line, NULL, NULL, TRUE, 0, NULL, NULL, &startup, &process);
      free(command_line);
      if (!created) return (int)GetLastError();

      WaitForSingleObject(process.hProcess, INFINITE);

      DWORD exit_code = 0;
      if (!GetExitCodeProcess(process.hProcess, &exit_code)) exit_code = 1;
      CloseHandle(process.hThread);
      CloseHandle(process.hProcess);
      return (int)exit_code;
    }

    int wmain(int argc, wchar_t **argv) {
      if (argc >= 3 && _wcsicmp(argv[1], L"/exec") == 0) {
        return run_exec(argc, argv, 2);
      }

      int target_index = 1;
      while (target_index < argc) {
        if (argv[target_index][0] == L'\0') {
          target_index++;
          continue;
        }
        if (!is_option(argv[target_index])) break;
        if (option_takes_value(argv[target_index]) && target_index + 1 < argc) {
          target_index += 2;
        } else {
          target_index++;
        }
      }

      if (target_index >= argc) {
        return 0;
      }

      int enqueue_result = enqueue_host_open_request(argv[target_index]);
      if (enqueue_result >= 0) return enqueue_result;
      return 31;
    }
    EOF

        $CC -municode -o start.exe start-shim.c
      '';

      installPhase = ''
        install -Dm755 start.exe "$out/bin/start.exe"
      '';
    };
  start64 = buildStartShim pkgs.pkgsCross.mingwW64;
  start32 = buildStartShim pkgs.pkgsCross.mingw32;
in
pkgs.runCommand "nix-overlayfs-start-shim-1.0.0" { } ''
  install -Dm755 ${start64}/bin/start.exe "$out/bin/start.exe"
  install -Dm755 ${start64}/bin/start.exe "$out/bin/x86_64/start.exe"
  install -Dm755 ${start32}/bin/start.exe "$out/bin/i686/start.exe"
''
