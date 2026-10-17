#!/usr/bin/env python3
"""Offline scan of ALL reachable public Git commits for common literal secrets.

No bytes of a potential secret are emitted to logs. History rewriting and key
revocation require explicit owner action outside this checker.
"""
from __future__ import annotations

import re
import subprocess

PATTERNS = {
    "private_key": re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----"),
    "github_pat": re.compile(rb"\b(?:gh[pousr]_[A-Za-z0-9]{28,}|github_pat_[A-Za-z0-9_]{20,})\b"),
    "model_key": re.compile(rb"\bsk-(?:proj-|live-)?[A-Za-z0-9_-]{28,}\b"),
    "google_api_key": re.compile(rb"\bAIza[A-Za-z0-9_-]{35}\b"),
    "static_bearer": re.compile(rb"(?i:Authorization)\s*[:=]\s*[\"']?(?i:Bearer)\s+[A-Za-z0-9._-]{30,}"),
    "literal_api_key_value": re.compile(rb"(?i:\bapi[_-]?key\b)\s*[:=]\s*[\"'][A-Za-z0-9_-]{28,}[\"']"),
}
EXTENSIONS = (
    ".swift", ".md", ".html", ".json", ".plist", ".yml", ".yaml",
    ".py", ".sh", ".rb", ".xcconfig", ".txt", ".pbxproj", ".env",
)
def git(*args: str) -> bytes:
    return subprocess.check_output(["git", *args])

def main() -> None:
    commits = git("rev-list", "--all").decode().splitlines()
    seen: set[str] = set()
    hits: list[tuple[str, str]] = []
    total_bytes = 0
    for commit in commits:
        tree = git("ls-tree", "-rz", commit)
        for raw in tree.split(b"\x00"):
            if not raw or b"\t" not in raw:
                continue
            info, rawpath = raw.split(b"\t", 1)
            parts = info.split()
            if len(parts) != 3 or parts[1] != b"blob":
                continue
            sha = parts[2].decode()
            if sha in seen:
                continue
            path = rawpath.decode(errors="replace")
            if not path.lower().endswith(EXTENSIONS):
                continue
            size = int(git("cat-file", "-s", sha))
            if size > 3_000_000:
                continue
            seen.add(sha)
            data = git("cat-file", "blob", sha)
            total_bytes += len(data)
            for kind, pattern in PATTERNS.items():
                if pattern.search(data):
                    hits.append((path, kind))
    if hits:
        for path, kind in sorted(set(hits))[:50]:
            print("HISTORICAL_SECRET_CANDIDATE", kind, path)
        raise SystemExit("Public Git history may contain credential literals; rotate and remediate")
    print(f"PUBLIC_GIT_HISTORY_PATTERN_SCAN_PASS commits={len(commits)} "
          f"unique_text_blobs={len(seen)} bytes_scanned={total_bytes}")

if __name__ == "__main__":
    main()
