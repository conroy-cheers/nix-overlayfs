{
  pkgs,
  ...
}:
let
  supervisor = pkgs.callPackage ../../lib/runtime-supervisor.nix { };

  termRespawn = pkgs.writeShellScript "runtime-supervisor-term-respawn" ''
    printf '%s\n' "$$" > "$NIX_OVERLAYFS_TEST_ROOT_PID"
    trap '
      ${pkgs.coreutils}/bin/sleep 30 &
      printf "%s\\n" "$!" > "$NIX_OVERLAYFS_TEST_REPLACEMENT_PID"
      exit 0
    ' TERM
    while :; do :; done
  '';

  stubborn = pkgs.writeShellScript "runtime-supervisor-stubborn" ''
    printf '%s\n' "$$" > "$NIX_OVERLAYFS_TEST_STUBBORN_PID"
    trap "" TERM
    while :; do ${pkgs.coreutils}/bin/sleep 1; done
  '';

  launchChildren = pkgs.writeShellScript "runtime-supervisor-launch-children" ''
    ${pkgs.util-linux}/bin/setsid ${termRespawn} &
    ${pkgs.util-linux}/bin/setsid ${stubborn} &
    while [ ! -s "$NIX_OVERLAYFS_TEST_ROOT_PID" ] \
      || [ ! -s "$NIX_OVERLAYFS_TEST_STUBBORN_PID" ]; do
      ${pkgs.coreutils}/bin/sleep 0.01
    done
    exit 23
  '';

  signalTarget = pkgs.writeShellScript "runtime-supervisor-signal-target" ''
    trap 'printf forwarded > "$NIX_OVERLAYFS_TEST_SIGNAL_RESULT"; exit 42' TERM
    printf ready > "$NIX_OVERLAYFS_TEST_SIGNAL_READY"
    while :; do ${pkgs.coreutils}/bin/sleep 1; done
  '';

  parentHarness = pkgs.writeShellScript "runtime-supervisor-parent-harness" ''
    ${supervisor}/bin/nix-overlayfs-runtime-supervisor \
      --term-timeout 1s --label parent-death-test -- ${signalTarget} &
    printf '%s\n' "$!" > "$NIX_OVERLAYFS_TEST_SUPERVISOR_PID"
    wait
  '';
in
pkgs.runCommand "runtime-supervisor-test"
  {
    nativeBuildInputs = [ supervisor ];
  }
  ''
    root_pid="$TMPDIR/root.pid"
    replacement_pid="$TMPDIR/replacement.pid"
    stubborn_pid="$TMPDIR/stubborn.pid"
    signal_ready="$TMPDIR/signal.ready"
    signal_result="$TMPDIR/signal.result"
    parent_signal_ready="$TMPDIR/parent-signal.ready"
    parent_signal_result="$TMPDIR/parent-signal.result"
    parent_supervisor_pid="$TMPDIR/parent-supervisor.pid"

    ${pkgs.coreutils}/bin/env $'DECOY=anything\nWINEPREFIX=/tmp/not-a-real-prefix' \
      ${pkgs.coreutils}/bin/sleep 30 &
    decoy_pid=$!
    trap '${pkgs.coreutils}/bin/kill "$decoy_pid" 2>/dev/null || true' EXIT

    status=0
    NIX_OVERLAYFS_TEST_ROOT_PID="$root_pid" \
    NIX_OVERLAYFS_TEST_REPLACEMENT_PID="$replacement_pid" \
    NIX_OVERLAYFS_TEST_STUBBORN_PID="$stubborn_pid" \
      ${supervisor}/bin/nix-overlayfs-runtime-supervisor \
        --term-timeout 100ms --label supervisor-test -- ${launchChildren} \
        || status=$?
    test "$status" -eq 23

    test -s "$replacement_pid"
    for pid_file in "$root_pid" "$replacement_pid" "$stubborn_pid"; do
      pid="$(<"$pid_file")"
      ! ${pkgs.coreutils}/bin/kill -0 "$pid" 2>/dev/null
    done
    ${pkgs.coreutils}/bin/kill -0 "$decoy_pid"

    NIX_OVERLAYFS_TEST_SIGNAL_READY="$signal_ready" \
    NIX_OVERLAYFS_TEST_SIGNAL_RESULT="$signal_result" \
      ${supervisor}/bin/nix-overlayfs-runtime-supervisor \
        --term-timeout 1s --label signal-test -- ${signalTarget} &
    supervisor_pid=$!
    while [ ! -e "$signal_ready" ]; do ${pkgs.coreutils}/bin/sleep 0.01; done
    ${pkgs.coreutils}/bin/kill -TERM "$supervisor_pid"
    status=0
    wait "$supervisor_pid" || status=$?
    test "$status" -eq 42
    test "$(<"$signal_result")" = forwarded

    NIX_OVERLAYFS_TEST_SIGNAL_READY="$parent_signal_ready" \
    NIX_OVERLAYFS_TEST_SIGNAL_RESULT="$parent_signal_result" \
    NIX_OVERLAYFS_TEST_SUPERVISOR_PID="$parent_supervisor_pid" \
      ${parentHarness} &
    parent_pid=$!
    while [ ! -e "$parent_signal_ready" ] \
      || [ ! -s "$parent_supervisor_pid" ]; do
      ${pkgs.coreutils}/bin/sleep 0.01
    done
    ${pkgs.coreutils}/bin/kill -KILL "$parent_pid"
    wait "$parent_pid" 2>/dev/null || true
    supervised_pid="$(<"$parent_supervisor_pid")"
    for attempt in $(${pkgs.coreutils}/bin/seq 1 200); do
      if ! ${pkgs.coreutils}/bin/kill -0 "$supervised_pid" 2>/dev/null; then break; fi
      ${pkgs.coreutils}/bin/sleep 0.01
    done
    ! ${pkgs.coreutils}/bin/kill -0 "$supervised_pid" 2>/dev/null
    test "$(<"$parent_signal_result")" = forwarded

    for invalid_duration in invalid nan inf -1s; do
      status=0
      ${supervisor}/bin/nix-overlayfs-runtime-supervisor \
        --term-timeout "$invalid_duration" -- ${pkgs.coreutils}/bin/touch "$TMPDIR/should-not-run" \
        || status=$?
      test "$status" -eq 2
    done
    test ! -e "$TMPDIR/should-not-run"

    touch "$out"
  ''
