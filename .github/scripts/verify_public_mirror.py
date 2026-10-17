#!/usr/bin/env python3
"""Fail-closed public mirror gate. Only eight SHA-identical original AppIcons."""
from __future__ import annotations

from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[2]
ICON_DIR = "aReuImpress-iPhone/Resources/Assets.xcassets/AppIcon.appiconset/"
ORIGINAL = {
    "icon_40.png": "6b84184cc92c7087f67e0d4a04d58a35f3fd1857",
    "icon_58.png": "894f3d52817c02158534936fd78e2a6601542f2e",
    "icon_60.png": "fcb469c6d79da5286f798283057526eabdabb0a5",
    "icon_80.png": "a78b88d4a2b010dfe5bdfa595828e5781493741e",
    "icon_87.png": "4ace8e7e0954af127c9942e50924581ca7bdca0d",
    "icon_120.png": "bd5bdf9a26ba2cae6d795c30d9f699bebeede322",
    "icon_180.png": "65d28cc1984cf706cce3f4059647a9a8ded31f58",
    "icon_1024.png": "f5a0edd2f317c7104441ee8798fb0fbf00cff9e5",
}
EXPECTED_MAPPING = Counter([
    ("iphone", "20x20", "2x", "icon_40.png"),
    ("iphone", "20x20", "3x", "icon_60.png"),
    ("iphone", "29x29", "2x", "icon_58.png"),
    ("iphone", "29x29", "3x", "icon_87.png"),
    ("iphone", "40x40", "2x", "icon_80.png"),
    ("iphone", "40x40", "3x", "icon_120.png"),
    ("iphone", "60x60", "2x", "icon_120.png"),
    ("iphone", "60x60", "3x", "icon_180.png"),
    ("ios-marketing", "1024x1024", "1x", "icon_1024.png"),
])
FORBIDDEN_SUFFIXES = (
    ".p12", ".p8", ".pem", ".mobileprovision", ".key", ".sqlite",
    ".sqlite3", ".db", ".heic", ".webp", ".gif", ".tif", ".tiff",
)
RASTER = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".heic", ".tif", ".tiff")
SENSITIVE = {
    "private_key": re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----"),
    "github_token": re.compile(rb"(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{20,})"),
    "llm_token": re.compile(rb"\bsk-(?:proj-|live-)?[A-Za-z0-9_-]{28,}\b"),
    "google_api_key": re.compile(rb"\bAIza[A-Za-z0-9_-]{35}\b"),
}

def git_blob_sha(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()

def main() -> None:
    names = subprocess.check_output(
        ["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
    tracked = set(filter(None, names))
    expected_raster = {ICON_DIR + name for name in ORIGINAL}
    real_raster = {name for name in tracked if name.lower().endswith(RASTER)}
    assert real_raster == expected_raster, (
        "P0 fail: unauthorized/missing original AppIcon raster files",
        sorted(real_raster ^ expected_raster))
    for name in sorted(tracked):
        lower = name.lower()
        assert not lower.startswith(("docs/", "pods/", "private/", ".obsidian/")), (
            "P2 fail: disallowed private directory", name)
        assert "/xcuserdata/" not in lower and not lower.endswith(FORBIDDEN_SUFFIXES), (
            "P2 fail: disallowed artifact", name)
        assert not lower.endswith(".env") and "/.env." not in lower, (
            "P2 fail: configuration secret", name)
        path = ROOT / name
        if not path.is_file() or path.stat().st_size > 3_000_000:
            continue
        if lower.endswith((".swift", ".py", ".yml", ".yaml", ".json",
                           ".plist", ".pbxproj", ".sh", ".rb", ".md",
                           ".txt", ".xcconfig", ".strings", ".lock")):
            data = path.read_bytes()
            for label, pattern in SENSITIVE.items():
                assert not pattern.search(data), ("P2 fail: credential signature", label, name)
    for name, expected_sha in ORIGINAL.items():
        data = (ROOT / ICON_DIR / name).read_bytes()
        assert git_blob_sha(data) == expected_sha, ("P0 fail: original SHA", name)
        assert data.startswith(bytes.fromhex("89504e470d0a1a0a")), (
            "P0 fail: invalid PNG signature", name)
        width, height = struct.unpack(">II", data[16:24])
        expected_size = int(name.removeprefix("icon_").removesuffix(".png"))
        assert (width, height) == (expected_size, expected_size), (
            "P0 fail: PNG dimensions", name, width, height)
        print("ORIGINAL_APPICON_SHA_PASS", name, expected_sha)
    spec = json.loads((ROOT / ICON_DIR / "Contents.json").read_text())
    actual = Counter((x.get("idiom"), x.get("size"), x.get("scale"),
                      x.get("filename")) for x in spec["images"])
    assert actual == EXPECTED_MAPPING, "P0 fail: AppIcon Contents.json size/idiom mapping"
    project = (ROOT / "aReuImpress-iPhone.xcodeproj/project.pbxproj").read_text()
    assert "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;" in project, (
        "P0 fail: Xcode AppIcon target configuration")
    builder = (ROOT / ".github/scripts/generate_neutral_assets.py").read_text()
    assert "paint(icons" not in builder and 'kind == "icon"' not in builder, (
        "P0 fail: placeholder generation may affect AppIcon")
    print("ORIGINAL_EIGHT_APPICONS_AND_CATALOG_PASS")
    print("PUBLIC_MIRROR_PRIVATE_ART_AND_CREDENTIAL_GATE_PASS")

if __name__ == "__main__":
    main()
