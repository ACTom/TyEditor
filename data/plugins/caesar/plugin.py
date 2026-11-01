#!/usr/bin/env python3
"""TyEditor plugin protocol v1 example: Caesar cipher.

This is a deliberately simple encryption/decryption demo, not secure
cryptography. Real secrets should use a vetted library and key management.
"""
import json
import sys

SHIFT = 3


def caesar(text: str, shift: int) -> str:
    out = []
    for ch in text:
        if "a" <= ch <= "z":
            out.append(chr((ord(ch) - ord("a") + shift) % 26 + ord("a")))
        elif "A" <= ch <= "Z":
            out.append(chr((ord(ch) - ord("A") + shift) % 26 + ord("A")))
        else:
            out.append(ch)
    return "".join(out)


def main() -> int:
    try:
        request = json.load(sys.stdin)
        command = request.get("command", "")
        context = request.get("context", {})
        text = context.get("selection", {}).get("text", "")
        if command == "encrypt":
            result = caesar(text, SHIFT)
        elif command == "decrypt":
            result = caesar(text, -SHIFT)
        else:
            raise ValueError("unknown command: " + command)
        response = {
            "api": 1,
            "ok": True,
            "actions": [{"type": "replace_selection", "text": result}],
        }
    except Exception as exc:
        response = {"api": 1, "ok": False, "message": str(exc)}
    json.dump(response, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
