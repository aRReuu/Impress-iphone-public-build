#!/usr/bin/env python3
"""Retired native-cloud-chat and credential exposure contract (no secret values printed)."""
from __future__ import annotations

from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "aReuImpress-iPhone"
TRACKED = set(filter(None, subprocess.check_output(
    ["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")))

# These modules were retired in favor of local review + explicit browser handoff.
BANNED_RELATIVE_PATHS = (
    "Model/ImLLM/", "Model/ImPollingChat/", "Model/ImPreChat/",
    "NetWork/ImNetWorkRequest", "NetWork/ImResponse/ImGeminiResponse.swift",
    "NetWork/ImResponse/ImpressResponse.swift",
    "Utils/Public/ImAutoGenerator/", "Utils/Public/ImFileManager/ImBackupManager.swift",
    "Utils/Public/ImSliderVC/",
    "VC/MainVCs/ImPollingChatVC/", "VC/SubVCs/ImPollingChatListVC/",
    "VC/SubVCs/ImPreChatVC/", "VC/SubVCs/ImLLMConfigVC/",
    "VC/SubVCs/ImSettingVC/ImSystemPromptViewController.swift",
    "View/ImLLM/", "View/ImPollingChat/",
    "ViewModel/ImPollingChat/", "ViewModel/ImPreChatList/",
    "ViewModel/ImSettings/ImSettingsViewModel.swift",
)
RETIRED_IDENTIFIERS = (
    "ImLLMModel", "ImPollingChat", "ImPreChat", "ImNetWorkRequest",
    "ImAutoGenerator", "ImBackupManager", "ImLLMConfigViewController",
    "ImSystemPromptViewController", "ImSettingsViewModel",
    "LLMModelDidChange", "didSelectChatSession",
)
SECRET_MARKERS = (
    re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----"),
    re.compile(rb"\b(?:gh[pousr]_[A-Za-z0-9]{28,}|github_pat_[A-Za-z0-9_]{20,})\b"),
    re.compile(rb"\bsk-(?:proj-|live-)?[A-Za-z0-9_-]{28,}\b"),
    re.compile(rb"\bAIza[A-Za-z0-9_-]{35}\b"),
)

def assert_clean() -> None:
    for name in TRACKED:
        if name.startswith("aReuImpress-iPhone/"):
            short = name[len("aReuImpress-iPhone/"):]
            assert not any(short.startswith(b) for b in BANNED_RELATIVE_PATHS), (
                "RETIRED_NATIVE_CHAT_SOURCE_STILL_TRACKED", name)
    swift = sorted(APP.rglob("*.swift"))
    # Prefix check catches suffixed model/controller references left in unrelated
    # features after removal (e.g. ImPollingChatListViewController in old UI).
    retired_prefixes = (
        "ImPollingChat", "ImPreChat", "ImLLM", "ImNetWorkRequest",
        "ImAutoGenerator", "ImBackupManager", "ImSliderViewController",
        "ImSettingsViewModel",
    )
    for path in swift:
        data = path.read_text()
        for prefix in retired_prefixes:
            assert not re.search(r"\b" + re.escape(prefix) + r"[A-Za-z0-9_]*\b", data), (
                "RETIRED_TYPE_REFERENCE", str(path.relative_to(ROOT)), prefix)
    project = (ROOT / "aReuImpress-iPhone.xcodeproj/project.pbxproj").read_text()
    for identifier in RETIRED_IDENTIFIERS:
        for p in swift:
            assert not re.search(r"\b" + re.escape(identifier) + r"\b", p.read_text()), (
                "RETIRED_NATIVE_CHAT_REFERENCE", str(p.relative_to(ROOT)), identifier)
        assert identifier not in project, ("RETIRED_PROJECT_REFERENCE", identifier)
    forbidden_suffix = (".p8", ".p12", ".pem", ".mobileprovision", ".key", ".env")
    for name in TRACKED:
        if name.startswith(("Docs/", "docs/", "Pods/")):
            continue  # The private source authority may retain internal documentation/deps.
        path = ROOT / name
        if not path.is_file():
            continue
        if name.lower().endswith(forbidden_suffix):
            raise AssertionError(("UNAUTHORIZED_SECRET_FILE", name))
        if not name.lower().endswith((".swift", ".py", ".sh", ".yml", ".yaml",
                                       ".json", ".plist", ".md", ".txt", ".pbxproj")):
            continue
        data = path.read_bytes()
        if len(data) > 3_000_000:
            continue
        for pattern in SECRET_MARKERS:
            assert not pattern.search(data), ("CREDENTIAL_LITERAL_IN_SOURCE", name)
    db = (APP / "DataBase/ImDBHandler.swift").read_text()
    assert "purgeRetiredChatTables()" in db
    for table in ("impress_llm_model", "impress_polling_chat", "impress_chat"):
        assert table in db, ("MISSING_LEGACY_PURGE", table)
    assert "imDatabase.drop(table: table)" in db
    assert "printSqlText()" not in db, "SQL_TRACE_MUST_NOT_LOG_PRIVATE_DATA"
    tab = (APP / "Base/ImTabBarViewController.swift").read_text()
    assert "ImpressV3ReviewViewController()" in tab and "ImpressNoteListTableViewController()" in tab
    vault = (APP / "Utils/Public/ImFileManager/ImObsidianManager.swift").read_text()
    assert re.search(r"productionWriteEnabled\s*=\s*false\b", vault)
    app = (APP / "Base/AppDelegate.swift").read_text()
    assert "SecItemDelete(query as CFDictionary)" in app
    assert '"com.impress.github.token"' in app
    web = (APP / "VC/SubVCs/ImWebVC/ImWebViewController.swift").read_text()
    assert "https://chat.deepseek.com/" in web
    assert "UIPasteboard.general.string" in web
    assert "forReviewHandoff" in web
    assert "evaluateJavaScript" not in web, "WEB_HANDOFF_MUST_NOT_AUTOSEND"
    print("RETIRED_NATIVE_CHAT_AND_USER_KEYS_GUARD_PASS")
    print("OBSIDIAN_READONLY_AND_EXPLICIT_WEB_HANDOFF_PASS")
    print("NO_TRACKED_LLM_OR_GITHUB_BACKUP_SECRET_SIGNATURE_PASS")

if __name__ == "__main__":
    assert_clean()
