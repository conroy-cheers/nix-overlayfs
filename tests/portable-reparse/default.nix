{ pkgs, overlayfsLib }:
pkgs.runCommand "portable-wine-reparse-test"
  {
    nativeBuildInputs = [ pkgs.python3 ];
  }
  ''
      export WINEPREFIX="$PWD/prefix"
      export LD_PRELOAD=${overlayfsLib.scripts.portableReparse}/lib/libwine-portable-reparse.so
      mkdir -p prefix/drive_c/alias prefix/drive_c/target outside
      echo payload > prefix/drive_c/target/check.txt
      python3 - <<'PY'
    import errno, os, struct
    from pathlib import Path
    root = Path(os.environ['WINEPREFIX'])
    target = r'\??\C:\target'.encode('utf-16-le')
    data = struct.pack('<IHHHHHH', 0xA0000003, 8 + len(target), 0, 0, len(target), 0, 0) + target
    fd = os.open(root / 'drive_c/alias', os.O_RDONLY | os.O_DIRECTORY)
    os.setxattr(fd, 'user.WINEREPARSE', data)
    assert os.getxattr(fd, 'user.WINEREPARSE') == data
    assert os.getxattr(root / 'drive_c/alias', 'user.WINEREPARSE') == data
    assert (root / 'drive_c/alias/.nix-overlayfs-winereparse').read_bytes() == data
    os.removexattr(fd, 'user.WINEREPARSE')
    try:
        os.getxattr(fd, 'user.WINEREPARSE')
    except OSError as e:
        assert e.errno == errno.ENODATA
    else:
        raise AssertionError('removed reparse record remained visible')
    os.setxattr(fd, 'user.WINEREPARSE', data)
    os.close(fd)
    os.rename(root / 'drive_c/alias', root / 'drive_c/alias?')
    for path, attribute in [('outside', 'user.WINEREPARSE'), ('prefix/drive_c/target', 'user.unrelated')]:
        try:
            os.setxattr(path, attribute, data)
        except OSError:
            pass
    assert not Path('outside/.nix-overlayfs-winereparse').exists()
    assert not (root / 'drive_c/target/.nix-overlayfs-winereparse').exists()
    PY
      ${overlayfsLib.scripts.portableReparse}/bin/normalize-wine-reparse.py "$WINEPREFIX"
      test ! -e "prefix/drive_c/alias?"
      test "$(readlink prefix/drive_c/alias)" = target
      test "$(cat prefix/drive_c/alias/check.txt)" = payload
      ! find prefix -name .nix-overlayfs-winereparse | grep .
      touch "$out"
  ''
