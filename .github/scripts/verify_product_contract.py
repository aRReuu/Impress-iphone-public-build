#!/usr/bin/env python3
"""Regression tripwire against reintroducing superseded Impress UI rules.

Static assertions are NOT a replacement for XCTest or real-device acceptance.
No network calls, private Vault reads, API access, signing or filesystem writes.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
contract = (ROOT / "PRODUCT_REQUIREMENTS_CURRENT.md").read_text(encoding="utf-8")
ledger_ids = set(re.findall(
    r"^\|\s*((?:NAV|LOOP|CARD|UI|AI|CHAT|CAL|LOCAL|SAFE)-\d{2})\s*\|",
    contract, flags=re.MULTILINE))
acceptance = set(re.findall(r"^\|\s*(ACCEPT-\d{2})\s*\|",
                            contract, flags=re.MULTILINE))
open_issues = set(re.findall(r"^\|\s*(OPEN-\d{2})\s*\|",
                             contract, flags=re.MULTILINE))
assert len(ledger_ids) >= 85, f"Requirement coverage declined: {len(ledger_ids)}"
assert len(acceptance) == 12, f"ACCEPT-01..12 incomplete: {sorted(acceptance)}"
assert len(open_issues) == 6, f"OPEN-01..06 incomplete: {sorted(open_issues)}"

def source(path):
    return (ROOT / path).read_text(encoding="utf-8")

review = source("aReuImpress-iPhone/VC/MainVCs/ImCardVC/ImpressV3ReviewViewController.swift")
memory = source("aReuImpress-iPhone/View/ImCard/ImMemoryCard/ImMemoryCardView.swift")
composer = source("aReuImpress-iPhone/VC/MainVCs/ImCardVC/ImpressV3CardComposerViewController.swift")
chat = source("aReuImpress-iPhone/Utils/Public/ImAI/ImpressAINativeChatViewController.swift")
repo = source("aReuImpress-iPhone/DataBase/V3/ReviewWCDBRepository.swift")
notes = source("aReuImpress-iPhone/VC/SubVCs/ImNoteListVC/ImMarkdownVC/ImMarkdownViewController.swift")
vault = source("aReuImpress-iPhone/Utils/Public/ImFileManager/ImObsidianManager.swift")
workflow = source(".github/workflows/public-ios-build.yml")

assert "contentHistoryAction" not in review, "Superseded review footer history returned"
assert "impress.composer.content-history" in composer, "Editor lost content history"
assert "questionTextView.setMarkdownText" in memory
assert "questionTextView.isScrollEnabled = true" in memory
assert "updateQuestionTextViewHeight(revealed: true)" in memory
assert "impress.ai.chat.history" in chat and "impress.ai.chat.new-discussion" in chat
assert "switchDiscussion(to" in chat and "flushBeforeSwitch()" in chat
assert "impress_v3_chat_session" in repo, "Chat local history authority missing"
assert "saveChatSession" in repo and "chatSessions(for sourceIdentity:" in repo
assert "impress.notes.ai-discussion" in notes, "Notes no longer opens shared Chat"
assert re.search(r"productionWriteEnabled\s*=\s*false\b", vault)
assert not re.search(r"productionWriteEnabled\s*=\s*true\b", vault)
assert "private" in contract.lower() or "私有" in contract
assert "xcode-27" in workflow, "iOS 26+ Xcode SDK regression"
print(f"PRODUCT_CONTRACT_STATIC_PASS: {len(ledger_ids)} requirements, "
      f"{len(acceptance)} acceptances, {len(open_issues)} open decisions")
