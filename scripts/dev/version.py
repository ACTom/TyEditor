#!/usr/bin/env python3
"""Read the project version from TyEditor.lpi and generate version.inc."""
from __future__ import annotations

import argparse
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def _text_version(project: Path) -> str:
    root = ET.parse(project).getroot()
    version_info = root.find(".//ProjectOptions/VersionInfo")
    if version_info is None:
        raise SystemExit(f"no <VersionInfo> block in {project}")

    string_table = version_info.find("StringTable")
    if string_table is not None:
        product_version = (string_table.get("ProductVersion") or "").strip()
        if product_version:
            return product_version

    def number(name: str) -> int:
        node = version_info.find(name)
        if node is None:
            return 0
        try:
            return int(node.get("Value", "0"))
        except ValueError as exc:
            raise SystemExit(f"invalid {name} in {project}") from exc

    return ".".join(
        str(number(name))
        for name in ("MajorVersionNr", "MinorVersionNr", "RevisionNr", "BuildNr")
    )


def _render_include(version: str) -> str:
    return (
        "// Generated from TyEditor.lpi by scripts/dev/version.py.\n"
        "// Do not edit by hand; change Project Options > Version Info instead.\n"
        f"const TyEditorVersion = '{version}';\n"
    )


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--print", action="store_true", help="print the project version")
    group.add_argument(
        "--write",
        nargs=2,
        metavar=("PROJECT", "INCLUDE"),
        help="read PROJECT and write the generated Pascal include",
    )
    group.add_argument(
        "--check",
        nargs=2,
        metavar=("PROJECT", "INCLUDE"),
        help="verify that INCLUDE matches PROJECT",
    )
    parser.add_argument("project", nargs="?", default="TyEditor.lpi")
    args = parser.parse_args(argv)

    if args.write:
        project = Path(args.write[0])
        include = Path(args.write[1])
        version = _text_version(project)
        include.write_text(_render_include(version), encoding="utf-8")
        print(version)
        return 0

    if args.check:
        project = Path(args.check[0])
        include = Path(args.check[1])
        version = _text_version(project)
        expected = _render_include(version)
        actual = include.read_text(encoding="utf-8") if include.exists() else ""
        if actual != expected:
            print(
                f"version include is out of date: {include}\n"
                f"expected version: {version}\n"
                "run scripts/dev/version.py --write TyEditor.lpi src/version.inc",
                file=sys.stderr,
            )
            return 1
        print(version)
        return 0

    project = Path(args.project)
    print(_text_version(project))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
