#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from pathlib import Path

from pypinyin import Style, lazy_pinyin, load_phrases_dict

INITIALS = [
    "zh", "ch", "sh", "b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h",
    "j", "q", "x", "r", "z", "c", "s", "y", "w",
]

ENGLISH_PHONE_MAP = {
    "jarvis": [
        ["JH", "AA1", "R", "V", "IH0", "S"],
        ["JH", "AA1", "R", "V", "AH0", "S"],
        ["JH", "AA1", "R", "V", "IH1", "S"],
    ],
    "javis": [
        ["JH", "AA1", "V", "IH0", "S"],
        ["JH", "AA1", "V", "AH0", "S"],
    ],
    "hey jarvis": [
        ["HH", "EY1", "JH", "AA1", "R", "V", "IH0", "S"],
        ["HH", "EY1", "JH", "AA1", "R", "V", "AH0", "S"],
    ],
    "嘿 jarvis": [
        ["HH", "EY1", "JH", "AA1", "R", "V", "IH0", "S"],
        ["HH", "EY1", "JH", "AA1", "R", "V", "AH0", "S"],
    ],
    "嘿jarvis": [
        ["HH", "EY1", "JH", "AA1", "R", "V", "IH0", "S"],
        ["HH", "EY1", "JH", "AA1", "R", "V", "AH0", "S"],
    ],
    "grok": [
        ["G", "R", "AA1", "K"],
    ],
    "hey grok": [
        ["HH", "EY1", "G", "R", "AA1", "K"],
    ],
    "嘿 grok": [
        ["HH", "EY1", "G", "R", "AA1", "K"],
    ],
    "嘿grok": [
        ["HH", "EY1", "G", "R", "AA1", "K"],
    ],
    "hey chatgpt": [
        ["HH", "EY1", "CH", "AE1", "T", "JH", "IY1", "P", "IY1", "T", "IY1"],
    ],
    "chatgpt": [
        ["CH", "AE1", "T", "JH", "IY1", "P", "IY1", "T", "IY1"],
    ],
    "chat gpt": [
        ["CH", "AE1", "T", "JH", "IY1", "P", "IY1", "T", "IY1"],
    ],
    "嘿 chatgpt": [
        ["HH", "EY1", "CH", "AE1", "T", "JH", "IY1", "P", "IY1", "T", "IY1"],
    ],
    "嘿chatgpt": [
        ["HH", "EY1", "CH", "AE1", "T", "JH", "IY1", "P", "IY1", "T", "IY1"],
    ],
    "hey gpt": [
        ["HH", "EY1", "JH", "IY1", "P", "IY1", "T", "IY1"],
    ],
    "gpt": [
        ["JH", "IY1", "P", "IY1", "T", "IY1"],
    ],
    "嘿 gpt": [
        ["HH", "EY1", "JH", "IY1", "P", "IY1", "T", "IY1"],
    ],
    "嘿gpt": [
        ["HH", "EY1", "JH", "IY1", "P", "IY1", "T", "IY1"],
    ],
    "gemini": [
        ["JH", "EH1", "M", "AH0", "N", "AY2"],
    ],
    "hey gemini": [
        ["HH", "EY1", "JH", "EH1", "M", "AH0", "N", "AY2"],
    ],
    "openclaw": [
        ["OW1", "P", "AH0", "N", "K", "L", "AO1"],
    ],
    "hey openclaw": [
        ["HH", "EY1", "OW1", "P", "AH0", "N", "K", "L", "AO1"],
    ],
    "嘿 openclaw": [
        ["HH", "EY1", "OW1", "P", "AH0", "N", "K", "L", "AO1"],
    ],
    "嘿openclaw": [
        ["HH", "EY1", "OW1", "P", "AH0", "N", "K", "L", "AO1"],
    ],
}


def split_pinyin_syllable(s: str) -> list[str]:
    s = s.strip().lower()
    if not s:
        return []
    for ini in INITIALS:
        if s.startswith(ini) and len(s) > len(ini):
            rest = s[len(ini):]
            return [ini, rest]
    return [s]


def phrase_to_tokens(phrase: str) -> list[list[str]]:
    normalized = phrase.strip().lower()
    normalized = re.sub(r"[，,。.!！?？]+", " ", normalized)
    normalized = re.sub(r"\s+", " ", normalized).strip()
    if normalized in ENGLISH_PHONE_MAP:
        return ENGLISH_PHONE_MAP[normalized]

    # Ensure wake phrase "小爪" is pronounced as xiao zhua
    load_phrases_dict({"小爪": [["xiǎo"], ["zhuǎ"]]})
    syllables = lazy_pinyin(normalized, style=Style.TONE, strict=False, errors="default")
    tokens: list[str] = []
    for syl in syllables:
        if syl.isascii() and syl.isalpha() and len(syl) > 1:
            tokens.append(syl.upper())
            continue
        parts = split_pinyin_syllable(syl)
        tokens.extend(parts)
    return [[t for t in tokens if t]]


def main() -> None:
    parser = argparse.ArgumentParser(description="Build sherpa-onnx KWS keywords.txt from Chinese phrase")
    parser.add_argument("--phrase", required=True, help="Wake phrase, e.g. 你好小爪")
    parser.add_argument("--label", default="WAKE", help="Keyword label after @")
    parser.add_argument("--out", required=True, help="Output keywords file")
    parser.add_argument("--append", action="store_true", help="Append to output file instead of overwrite")
    args = parser.parse_args()

    token_lines = phrase_to_tokens(args.phrase)
    if not token_lines:
        raise SystemExit("No tokens generated. Please check phrase input.")

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    lines = [f"{' '.join(tokens)} @{args.label}" for tokens in token_lines]
    if args.append and out.exists():
        with out.open("a", encoding="utf-8") as f:
            for line in lines:
                f.write(line + "\n")
    else:
        out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Saved: {out}")
    for line in lines:
        print(f"Line : {line}")


if __name__ == "__main__":
    main()
