#!/usr/bin/env python3
"""Create an installable .typlugin package from a plugin directory."""
from __future__ import annotations

import json
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def fail(message: str) -> int:
    print(f"error: {message}", file=sys.stderr)
    return 1


def main(argv: list[str]) -> int:
    if len(argv) not in (2, 3):
        print("usage: package-plugin.py <plugin-dir> [output.typlugin]", file=sys.stderr)
        return 2
    plugin_dir = Path(argv[1]).resolve()
    manifest_path = plugin_dir / "plugin.json"
    if not manifest_path.is_file():
        return fail(f"missing manifest: {manifest_path}")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except Exception as exc:
        return fail(f"invalid manifest: {exc}")
    for field in ("schema", "api", "id", "name", "version", "runtime", "commands"):
        if field not in manifest:
            return fail(f"manifest is missing required field: {field}")
    if manifest["schema"] != 1 or manifest["api"] != 1:
        return fail("unsupported schema or API version")
    plugin_id = str(manifest["id"])
    if not plugin_id or "/" in plugin_id or "\\" in plugin_id or ":" in plugin_id:
        return fail("invalid plugin id")
    commands = manifest.get("commands")
    if not isinstance(commands, list) or not commands:
        return fail("manifest must declare at least one command")
    for command in commands:
        if not isinstance(command, dict) or not command.get("id") or not command.get("title"):
            return fail("each command needs an id and title")

    if len(argv) == 3:
        output = Path(argv[2]).resolve()
    else:
        output = ROOT / "dist" / "plugins" / f"{plugin_id}-{manifest['version']}.typlugin"
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()

    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(plugin_dir.rglob("*")):
            if path.is_dir():
                continue
            if path.name.startswith("."):
                continue
            if "__pycache__" in path.parts:
                continue
            if path.suffix == ".typlugin":
                continue
            archive.write(path, path.relative_to(plugin_dir).as_posix())
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
