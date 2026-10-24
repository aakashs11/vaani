#!/usr/bin/env python3
# Vaani modification, 2026: product identity and compatibility; see docs/provenance.md.
"""Prepare a new workspace from private backups. Never modifies a live app."""
import argparse
import datetime as dt
import json
from pathlib import Path
import sqlite3
import uuid
import wave

APPLE_EPOCH = 978307200


def apple_date(value):
    parsed = dt.datetime.fromisoformat(value.strip().replace("Z", "+00:00").replace(" +", "+"))
    if parsed.tzinfo is None:
        raise ValueError("Timestamp has no timezone")
    return parsed.timestamp() - APPLE_EPOCH


def identifier(source, key):
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"vaani-import:{source}:{key}")).upper()


def prepare(workspace, legacy):
    state = json.loads(workspace.read_text())
    original = {row["id"]: dict(row) for row in state["history"]}
    seen = set(original)
    report = {"added": {}, "skipped_empty": {}, "invalid": [], "vocabulary_added": 0}

    def add(source, key, raw, text, when, duration, language="auto"):
        uid = identifier(source, key)
        if uid in seen:
            return
        raw, text = raw or "", text or raw or ""
        if not text.strip():
            report["skipped_empty"][source] = report["skipped_empty"].get(source, 0) + 1
            return
        try:
            date = float(when) if isinstance(when, (float, int)) else apple_date(when)
            seconds = max(0, float(duration or 0))
        except (ValueError, TypeError, AttributeError):
            report["invalid"].append({"source": source, "id": str(key), "reason": "invalid timestamp or duration"})
            return
        state["history"].append({
            "id": uid, "createdAt": date, "text": text, "rawText": raw, "duration": seconds,
            "modelName": f"Imported · {source}", "language": language or "auto", "vocabularyFixes": 0,
        })
        seen.add(uid)
        report["added"][source] = report["added"].get(source, 0) + 1

    def rows(path, query):
        with sqlite3.connect(f"file:{path}?mode=ro", uri=True) as conn:
            conn.row_factory = sqlite3.Row
            return list(conn.execute(query))

    ff = legacy / "FreeFlow"
    for row in rows(ff / "PipelineHistory.sqlite", "SELECT * FROM ZPIPELINEHISTORYENTRY"):
        duration = 0
        audio = row["ZAUDIOFILENAME"]
        if audio:
            candidates = list(ff.rglob(Path(audio).name))
            if candidates:
                with wave.open(str(candidates[0])) as wav:
                    duration = wav.getnframes() / wav.getframerate()
        key = row["ZID"].hex() if isinstance(row["ZID"], bytes) else row["Z_PK"]
        add("FreeFlow", key, row["ZRAWTRANSCRIPT"], row["ZPOSTPROCESSEDTRANSCRIPT"],
            row["ZTIMESTAMP"], duration)

    for row in rows(legacy / "Srota/srota.db", "SELECT * FROM dictations"):
        add("Srota", row["id"], row["raw_text"], row["raw_text"], row["timestamp"], row["duration_seconds"])

    flow = legacy / "Wispr Flow"
    # Current records win; older snapshots only contribute missing IDs.
    databases = [flow / "flow.sqlite", *sorted((flow / "backups").glob("*.sqlite"), reverse=True)]
    vocab_seen = {entry["phrase"].casefold() for entry in state["vocabulary"]}
    dictionary_ids = set()
    for database in databases:
        for row in rows(database, "SELECT * FROM History"):
            add("Wispr Flow", row["transcriptEntityId"], row["asrText"],
                row["editedText"] or row["pastedText"] or row["formattedText"] or row["asrText"],
                row["timestamp"], row["duration"], row["language"])
        for row in rows(database, "SELECT * FROM Dictionary"):
            if row["id"] in dictionary_ids:
                continue
            dictionary_ids.add(row["id"])
            phrase = row["phrase"].strip()
            if row["isDeleted"] or not phrase or phrase.casefold() in vocab_seen:
                continue
            state["vocabulary"].append({
                "id": identifier("Wispr Dictionary", row["id"]), "phrase": phrase,
                "replacement": row["replacement"] or "", "learned": not bool(row["manualEntry"]),
            })
            vocab_seen.add(phrase.casefold())
            report["vocabulary_added"] += 1
    state["history"].sort(key=lambda row: row["createdAt"], reverse=True)
    assert len({row["id"] for row in state["history"]}) == len(state["history"])
    restored = {row["id"]: row for row in state["history"]}
    assert all(restored[key] == value for key, value in original.items()), "Original history changed"
    assert state["settings"] == json.loads(workspace.read_text())["settings"], "Settings changed"
    report["history_total"] = len(state["history"])
    report["vocabulary_total"] = len(state["vocabulary"])
    return state, report


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--legacy", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    assert apple_date("2001-01-01T00:00:00Z") == 0
    assert apple_date("2001-01-01 00:00:00.000 +00:00") == 0
    state, report = prepare(args.workspace, args.legacy)
    with args.output.open("x") as output:
        json.dump(state, output, ensure_ascii=False, indent=2)
    args.output.chmod(0o600)
    print(json.dumps(report, indent=2))
