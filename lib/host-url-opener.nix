{
  writeShellScriptBin,
  systemd,
  util-linux,
  xdg-utils,
}:

writeShellScriptBin "nix-overlayfs-open-url" ''
  set -u

  direct=0
  if [ "''${1:-}" = "--direct" ]; then
    direct=1
    shift
  fi

  if [ "$#" -lt 1 ]; then
    exit 64
  fi

  target="$1"
  shift || true

  if [ "$direct" != 1 ] && [ -n "''${NIX_OVERLAYFS_HOST_OPEN_DIR:-}" ]; then
    request_dir="$NIX_OVERLAYFS_HOST_OPEN_DIR"
    mkdir -p "$request_dir"
    request_file="$(mktemp "$request_dir/request.XXXXXXXXXX.tmp")"
    final_file="''${request_file%.tmp}"
    printf '%s\n' "$target" > "$request_file"
    mv "$request_file" "$final_file"
    exit 0
  fi

  systemd_env=()
  for name in \
    BROWSER \
    DBUS_SESSION_BUS_ADDRESS \
    DISPLAY \
    WAYLAND_DISPLAY \
    XAUTHORITY \
    XDG_CURRENT_DESKTOP \
    XDG_RUNTIME_DIR \
    XDG_SESSION_TYPE
  do
    value="''${!name-}"
    if [ -n "$value" ]; then
      systemd_env+=(--setenv="$name=$value")
    fi
  done

  if [ -n "''${XDG_RUNTIME_DIR-}" ] && [ -S "''${XDG_RUNTIME_DIR}/bus" ]; then
    if ${systemd}/bin/systemd-run \
      --user \
      --collect \
      --quiet \
      --description="Open URL from Wine prefix" \
      "''${systemd_env[@]}" \
      ${xdg-utils}/bin/xdg-open "$target" >/dev/null 2>&1
    then
      exit 0
    fi
  fi

  if ${util-linux}/bin/setsid -f ${xdg-utils}/bin/xdg-open "$target" >/dev/null 2>&1; then
    exit 0
  fi

  exec ${xdg-utils}/bin/xdg-open "$target"
''
