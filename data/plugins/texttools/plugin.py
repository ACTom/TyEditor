#!/usr/bin/env python3
"""TyEditor plugin protocol v1 example: selection/document formatting."""
import json
import sys


def trim_line(line: str) -> str:
    body = line.rstrip("\r\n")
    ending = line[len(body):]
    return body.rstrip(" \t") + ending


def main() -> int:
    try:
        request = json.load(sys.stdin)
        command = request.get("command", "")
        context = request.get("context", {})
        selection = context.get("selection", {}).get("text", "")
        if command == "upper":
            actions = [{"type": "replace_selection", "text": selection.upper()}]
        elif command == "lower":
            actions = [{"type": "replace_selection", "text": selection.lower()}]
        elif command == "title":
            actions = [{"type": "replace_selection", "text": selection.title()}]
        elif command == "trim":
            text = context.get("text", "")
            text = "".join(trim_line(line) for line in text.splitlines(keepends=True))
            actions = [{"type": "replace_document", "text": text}]
        else:
            raise ValueError("unknown command: " + command)
        response = {"api": 1, "ok": True, "actions": actions}
    except Exception as exc:
        response = {"api": 1, "ok": False, "message": str(exc)}
    json.dump(response, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
