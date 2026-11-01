#!/usr/bin/env python3
"""TyEditor plugin protocol v1 example: JSON formatting."""
import json
import sys


def main() -> int:
    try:
        request = json.load(sys.stdin)
        command = request.get("command", "")
        options = request.get("options", {})
        text = request.get("context", {}).get("text", "")
        value = json.loads(text)
        if command == "minify":
            result = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
        elif command == "format":
            indent = int(options.get("indent", "2"))
            sort_keys = str(options.get("sort_keys", "false")).lower() == "true"
            result = json.dumps(value, ensure_ascii=False, indent=indent, sort_keys=sort_keys)
        else:
            raise ValueError("unknown command: " + command)
        response = {
            "api": 1,
            "ok": True,
            "actions": [{"type": "replace_document", "text": result}],
        }
    except json.JSONDecodeError:
        response = {
            "api": 1,
            "ok": False,
            "message_key": "error.invalid_json",
            "message": "Invalid JSON",
        }
    except Exception as exc:
        response = {"api": 1, "ok": False, "message": str(exc)}
    json.dump(response, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
