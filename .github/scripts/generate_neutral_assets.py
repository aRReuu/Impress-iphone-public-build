#!/usr/bin/env python3
"""Generate neutral build-only raster assets. No private or third-party images."""
from __future__ import annotations

import hashlib
import json
import struct
import subprocess
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RES = ROOT / "aReuImpress-iPhone" / "Resources"


def chunk(tag: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + tag
        + payload
        + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
    )


def paint(path: Path, width: int, height: int, kind: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    compressor = zlib.compressobj(level=9)
    parts = []
    for y in range(height):
        row = bytearray([0])
        for x in range(width):
            t = y / max(height - 1, 1)
            if kind == "icon":
                color = (25 + int(t * 15), 31 + int(t * 12), 53 + int(t * 20))
                stem = (width * 0.44 <= x <= width * 0.56 and height * 0.30 <= y <= height * 0.72)
                cross = (width * 0.32 <= x <= width * 0.68 and
                         (height * 0.30 <= y <= height * 0.39 or
                          height * 0.63 <= y <= height * 0.72))
                if stem or cross:
                    color = (215, 243, 239)
            elif kind == "wallpaper":
                color = (24 + int(t * 25), 31 + int(t * 20), 50 + int(t * 31))
            elif kind == "portrait":
                color = (47 + int(t * 20), 62 + int(t * 20), 82 + int(t * 22))
                cx, cy, radius = width * 0.50, height * 0.37, min(width, height) * 0.145
                if (x - cx) ** 2 + (y - cy) ** 2 <= radius ** 2:
                    color = (165, 179, 187)
                if height * 0.57 < y < height * 0.84 and abs(x - cx) < width * 0.24:
                    color = (165, 179, 187)
            else:
                palettes = {
                    "again": (184, 74, 79),
                    "hard": (174, 123, 60),
                    "easy": (60, 143, 128),
                    "normal": (77, 115, 161),
                }
                color = palettes.get(kind, (77, 115, 161))
                cx, cy = width // 2, height // 2
                if (x - cx) ** 2 + (y - cy) ** 2 < (min(width, height) * 0.26) ** 2:
                    color = (233, 242, 246)
            row.extend(color)
        parts.append(compressor.compress(bytes(row)))
    parts.append(compressor.flush())
    compressed = b"".join(parts)
    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    blob = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) +
            chunk(b"IDAT", compressed) + chunk(b"IEND", b""))
    path.write_bytes(blob)


def main() -> None:
    icons = RES / "Assets.xcassets" / "AppIcon.appiconset"
    for edge in (40, 58, 60, 80, 87, 120, 180, 1024):
        paint(icons / f"icon_{edge}.png", edge, edge, "icon")
    card_dir = RES / "ImCard"
    for rating in ("again", "hard", "easy", "normal"):
        paint(card_dir / f"imcard_{rating}@2x.png", 120, 120, rating)
    paint(card_dir / "imcard_wallpaper.png", 720, 1100, "wallpaper")
    temporary = RES / "neutral_photo.png"
    paint(temporary, 600, 600, "portrait")
    subprocess.run(
        ["sips", "-s", "format", "jpeg", str(temporary),
         "--out", str(RES / "grandmother.jpg")],
        check=True, stdout=subprocess.DEVNULL
    )
    temporary.unlink()
    outputs = sorted(
        list(icons.glob("icon_*.png"))
        + list(card_dir.glob("*.png")) + [RES / "grandmother.jpg"]
    )
    print(json.dumps({
        "count": len(outputs),
        "generated": [{"path": str(f.relative_to(ROOT)),
                       "sha256": hashlib.sha256(f.read_bytes()).hexdigest()}
                      for f in outputs]
    }, indent=2))


if __name__ == "__main__":
    main()
