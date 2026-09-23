"""Install the Windows release export template without downloading the whole 1.2 GB package.

Godot's official host (downloads.godotengine.org) serves the template bundle
(`Godot_v<version>-stable_export_templates.tpz`, a plain ZIP) with HTTP range
support, so the single template binary the Windows Desktop preset needs can be
pulled out of the middle of the archive.

Usage:
    python tools/fetch_export_templates.py                # 4.7.2.stable, default target dir
    python tools/fetch_export_templates.py --version 4.7.2 --templates-dir "D:/templates"

Installs into %APPDATA%/Godot/export_templates/<version>.stable/, which is where
the editor looks for templates used by:
    Godot_v4.7.2-stable_win64_console.exe --headless --path . \
        --export-release "Windows Desktop" "dist/CrimsonTide.exe"
"""

from __future__ import annotations

import argparse
import os
import struct
import sys
import urllib.request
import zlib

HOST = "https://downloads.godotengine.org"
# The mirror answers 403 to range requests that carry no User-Agent.
USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) godot-template-fetch/1.0"
EOCD_SIG = b"PK\x05\x06"
EOCD64_LOCATOR_SIG = b"PK\x06\x07"
EOCD64_SIG = b"PK\x06\x06"
CENTRAL_SIG = b"PK\x01\x02"
LOCAL_SIG = b"PK\x03\x04"
CHUNK = 8 * 1024 * 1024


def remote_size(url: str) -> int:
    request = urllib.request.Request(url, headers={"Range": "bytes=0-0", "User-Agent": USER_AGENT})
    with urllib.request.urlopen(request) as response:
        content_range = response.headers.get("Content-Range")
        if not content_range:
            length = response.headers.get("Content-Length")
            if not length:
                raise RuntimeError("server returned neither Content-Range nor Content-Length")
            return int(length)
        return int(content_range.rsplit("/", 1)[1])


def fetch(url: str, start: int, end: int) -> bytes:
    """Inclusive byte range fetch, retrying in smaller pieces on short reads."""
    request = urllib.request.Request(url, headers={"Range": f"bytes={start}-{end}", "User-Agent": USER_AGENT})
    with urllib.request.urlopen(request) as response:
        data = response.read()
    expected = end - start + 1
    if len(data) == expected:
        return data
    if len(data) > expected:
        return data[:expected]
    # Some mirrors cap a single range response; stitch the remainder.
    return data + fetch(url, start + len(data), end)


def central_directory(url: str, size: int) -> list[tuple[str, int, int, int, int]]:
    """Return (name, local_header_offset, compressed_size, uncompressed_size, method)."""
    tail_start = max(0, size - (1 << 20))
    tail = fetch(url, tail_start, size - 1)
    locator = tail.rfind(EOCD64_LOCATOR_SIG)
    if locator >= 0:
        eocd64_offset = struct.unpack_from("<Q", tail, locator + 8)[0]
        header = fetch(url, eocd64_offset, eocd64_offset + 55)
        if header[:4] != EOCD64_SIG:
            raise RuntimeError("ZIP64 end of central directory not found")
        count = struct.unpack_from("<Q", header, 32)[0]
        directory_size = struct.unpack_from("<Q", header, 40)[0]
        directory_offset = struct.unpack_from("<Q", header, 48)[0]
    else:
        index = tail.rfind(EOCD_SIG)
        if index < 0:
            raise RuntimeError("end of central directory not found")
        count, directory_size, directory_offset = struct.unpack_from("<HII", tail, index + 10)

    directory = fetch(url, directory_offset, directory_offset + directory_size - 1)
    entries: list[tuple[str, int, int, int, int]] = []
    cursor = 0
    while cursor < len(directory) and directory[cursor : cursor + 4] == CENTRAL_SIG:
        method, = struct.unpack_from("<H", directory, cursor + 10)
        compressed, uncompressed = struct.unpack_from("<II", directory, cursor + 20)
        name_length, extra_length, comment_length = struct.unpack_from("<HHH", directory, cursor + 28)
        local_offset, = struct.unpack_from("<I", directory, cursor + 42)
        name_start = cursor + 46
        name = directory[name_start : name_start + name_length].decode("utf-8", "replace")
        extra = directory[name_start + name_length : name_start + name_length + extra_length]
        # Unpack ZIP64 extended information when the 32-bit fields are saturated.
        if local_offset == 0xFFFFFFFF or compressed == 0xFFFFFFFF or uncompressed == 0xFFFFFFFF:
            field = 0
            while field + 4 <= len(extra):
                header_id, data_size = struct.unpack_from("<HH", extra, field)
                if header_id == 0x0001:
                    body = extra[field + 4 : field + 4 + data_size]
                    position = 0
                    if uncompressed == 0xFFFFFFFF:
                        uncompressed = struct.unpack_from("<Q", body, position)[0]
                        position += 8
                    if compressed == 0xFFFFFFFF:
                        compressed = struct.unpack_from("<Q", body, position)[0]
                        position += 8
                    if local_offset == 0xFFFFFFFF:
                        local_offset = struct.unpack_from("<Q", body, position)[0]
                    break
                field += 4 + data_size
        entries.append((name, local_offset, compressed, uncompressed, method))
        cursor = name_start + name_length + extra_length + comment_length

    if len(entries) != count:
        print(f"note: expected {count} entries, parsed {len(entries)}", file=sys.stderr)
    return entries


def extract(url: str, name: str, offset: int, compressed: int, uncompressed: int, method: int) -> bytes:
    header = fetch(url, offset, offset + 29)
    if header[:4] != LOCAL_SIG:
        raise RuntimeError(f"bad local header for {name}")
    name_length, extra_length = struct.unpack_from("<HH", header, 26)
    data_start = offset + 30 + name_length + extra_length
    raw = fetch(url, data_start, data_start + compressed - 1)
    if method == 0:
        payload = raw
    elif method == 8:
        payload = zlib.decompress(raw, -15)
    else:
        raise RuntimeError(f"unsupported compression method {method} for {name}")
    if len(payload) != uncompressed:
        raise RuntimeError(f"size mismatch for {name}: {len(payload)} != {uncompressed}")
    return payload


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--version", default="4.7.2", help="Godot version, e.g. 4.7.2")
    parser.add_argument("--flavor", default="stable", help="release flavor, e.g. stable")
    parser.add_argument(
        "--templates-dir",
        default=os.path.join(os.environ.get("APPDATA", ""), "Godot", "export_templates"),
        help="root of the editor's export_templates directory",
    )
    parser.add_argument(
        "--files",
        nargs="*",
        default=["templates/windows_release_x86_64.exe", "templates/version.txt"],
        help="archive members to extract",
    )
    parser.add_argument("--url", default="", help="override the archive URL")
    options = parser.parse_args()

    version = f"{options.version}.{options.flavor}"
    # The official endpoint 302-redirects to a range-capable object-storage mirror.
    url = options.url or (
        f"{HOST}/?version={options.version}&flavor={options.flavor}"
        "&slug=export_templates.tpz&platform=templates"
    )
    target_dir = os.path.join(options.templates_dir, version)
    os.makedirs(target_dir, exist_ok=True)

    size = remote_size(url)
    print(f"archive: {url} ({size / 1048576:.1f} MiB)")

    entries = {name: entry for entry in central_directory(url, size) for name in [entry[0]]}
    wanted = []
    for name in options.files:
        if name not in entries:
            hits = [key for key in entries if key.endswith(os.path.basename(name))]
            if not hits:
                print(f"error: {name} not present in archive", file=sys.stderr)
                return 1
            name = hits[0]
        wanted.append(name)

    for name in wanted:
        _, offset, compressed, uncompressed, method = entries[name]
        destination = os.path.join(target_dir, os.path.basename(name))
        if os.path.exists(destination) and os.path.getsize(destination) == uncompressed:
            print(f"skip (already installed): {destination}")
            continue
        print(f"fetching {name}: {uncompressed / 1048576:.1f} MiB ...")
        payload = extract(url, name, offset, compressed, uncompressed, method)
        with open(destination, "wb") as handle:
            handle.write(payload)
        print(f"wrote {destination}")

    print(f"templates ready in {target_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
