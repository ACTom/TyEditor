#!/usr/bin/env python3
"""TyEditor plugin protocol v1 example: call an external formatter."""
import json
import shutil
import subprocess
import sys


def main() -> int:
    try:
        request = json.load(sys.stdin)
        command = request.get("command", "")
        context = request.get("context", {})
        if command == "selection":
            text = context.get("selection", {}).get("text", "")
            action = "replace_selection"
        elif command == "document":
            text = context.get("text", "")
            action = "replace_document"
        else:
            raise ValueError("unknown command: " + command)

        executable = shutil.which("clang-format")
        if not executable:
            response = {
                "api": 1,
                "ok": False,
                "message_key": "error.not_found",
                "message": "clang-format was not found on PATH.",
            }
        else:
            result = subprocess.run(
                [executable, "-style=LLVM"],
                input=text,
                text=True,
                capture_output=True,
                timeout=8,
                check=False,
            )
            if result.returncode != 0:
                response = {
                    "api": 1,
                    "ok": False,
                    "message_key": "error.failed",
                    "message": result.stderr.strip() or "clang-format failed.",
                }
            else:
                response = {
                    "api": 1,
                    "ok": True,
                    "actions": [{"type": action, "text": result.stdout}],
                }
    except Exception as exc:
        response = {"api": 1, "ok": False, "message": str(exc)}
    json.dump(response, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
