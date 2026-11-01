#!/usr/bin/env python3
"""TyEditor plugin protocol v1 example: Base64 encode/decode."""
import base64
import json
import sys


def main() -> int:
    try:
        request = json.load(sys.stdin)
        command = request.get("command", "")
        context = request.get("context", {})
        text = context.get("selection", {}).get("text", "")
        if command == "encode":
            result = base64.b64encode(text.encode("utf-8")).decode("ascii")
        elif command == "decode":
            result = base64.b64decode(text, validate=True).decode("utf-8")
        else:
            raise ValueError("unknown command: " + command)
        response = {
            "api": 1,
            "ok": True,
            "actions": [{"type": "replace_selection", "text": result}],
        }
    except Exception as exc:
        response = {
            "api": 1,
            "ok": False,
            "message_key": "error.decode",
            "message": str(exc),
        }
    json.dump(response, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
