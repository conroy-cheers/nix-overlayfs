import os
from pathlib import Path
import struct
import sys

MARKER = ".nix-overlayfs-winereparse"


def normalize(prefix):
    prefix = Path(prefix).resolve()
    records = []
    for directory, _, files in os.walk(prefix, followlinks=False):
        if MARKER in files:
            records.append(Path(directory) / MARKER)
    for record in records:
        data = record.read_bytes()
        if len(data) < 16:
            raise ValueError(f"truncated reparse record: {record}")
        tag, length, _ = struct.unpack_from("<IHH", data)
        if length + 8 != len(data):
            raise ValueError(f"invalid reparse record length: {record}")
        offset, count = struct.unpack_from("<HH", data, 8)
        if tag == 0xA0000003:
            start, relative = 16, False
        elif tag == 0xA000000C and len(data) >= 20:
            start, relative = 20, bool(struct.unpack_from("<I", data, 16)[0] & 1)
        else:
            raise ValueError(f"unsupported directory reparse tag {tag:#x}: {record}")
        if count % 2 or offset % 2 or start + offset + count > len(data):
            raise ValueError(f"invalid reparse target: {record}")
        target = data[start + offset:start + offset + count].decode("utf-16-le")
        if relative:
            destination = record.parent.parent / target.replace("\\", "/")
        else:
            if target.startswith("\\??\\"):
                target = target[4:]
            if not target.lower().startswith("c:\\"):
                raise ValueError(f"reparse target outside drive C: {target}")
            destination = prefix / "drive_c" / target[3:].replace("\\", "/")
        # Keep links relocatable when the layer moves into the store or a mount.
        destination = Path(os.path.abspath(destination))
        destination.relative_to(prefix)
        contents = list(record.parent.iterdir())
        if contents != [record]:
            raise ValueError(f"refusing to replace nonempty reparse directory: {record.parent}")
        # Wine stores reparse directories with a '?' suffix while running.
        linkpath = record.parent
        if linkpath.name.endswith("?"):
            linkpath = linkpath.with_name(linkpath.name[:-1])
            if os.path.lexists(linkpath):
                raise ValueError(f"reparse link destination already exists: {linkpath}")
        link = os.path.relpath(destination, linkpath.parent)
        record.unlink()
        record.parent.rmdir()
        linkpath.symlink_to(link, target_is_directory=True)


if __name__ == "__main__":
    normalize(sys.argv[1])
