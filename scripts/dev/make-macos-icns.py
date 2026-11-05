#!/usr/bin/env python3
"""Generate the macOS application icon from the shared 1024px artwork.

macOS Big Sur and later expect app icons on a 1024x1024 canvas with the
rounded-square artwork centred in an 824x824 area.  The shared artwork already
uses the same 22.5% corner-radius ratio, so this script scales the opaque
artwork into the macOS grid, adds a subtle drop shadow, and writes a modern
.icns containing both legacy and Retina representation types.

Only maintainers need Pillow; normal builds consume the committed .icns file.
"""

from __future__ import annotations

import argparse
import struct
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

CANVAS = 1024
CONTENT = 824
RADIUS = 185.4
SHADOW_BLUR = 18
SHADOW_OFFSET = (0, 12)
SHADOW_OPACITY = 0.30
SUPERSAMPLE = 4

# ICNS type -> pixel size. Both legacy and Retina types are included so that
# Finder and the Dock pick a sharp representation on every display.
ICNS_TYPES = (
    ("icp4", 16),
    ("icp5", 32),
    ("ic07", 128),
    ("ic08", 256),
    ("ic09", 512),
    ("ic10", 1024),
    ("ic11", 32),
    ("ic12", 64),
    ("ic13", 256),
    ("ic14", 512),
)


def rounded_mask(size: int, radius: float) -> Image.Image:
    """Return an antialiased rounded-rectangle mask."""
    scale = SUPERSAMPLE
    large = Image.new("L", (size * scale, size * scale), 0)
    draw = ImageDraw.Draw(large)
    draw.rounded_rectangle(
        (0, 0, size * scale - 1, size * scale - 1),
        radius=radius * scale,
        fill=255,
    )
    return large.resize((size, size), Image.Resampling.LANCZOS)


def build_canvas(source: Path) -> Image.Image:
    artwork = Image.open(source).convert("RGBA")
    bbox = artwork.getchannel("A").getbbox()
    if bbox is None:
        raise SystemExit(f"{source}: artwork is fully transparent")
    artwork = artwork.crop(bbox)
    artwork = artwork.resize((CONTENT, CONTENT), Image.Resampling.LANCZOS)

    # Re-apply the rounded shape after scaling so the edge stays clean and
    # matches the macOS corner-radius ratio exactly.
    mask = rounded_mask(CONTENT, RADIUS)
    artwork.putalpha(Image.composite(artwork.getchannel("A"), Image.new("L", artwork.size, 0), mask))

    shadow_alpha = Image.new("L", (CANVAS, CANVAS), 0)
    shadow_alpha.paste(
        artwork.getchannel("A").point(lambda value: int(value * SHADOW_OPACITY)),
        ((CANVAS - CONTENT) // 2 + SHADOW_OFFSET[0], (CANVAS - CONTENT) // 2 + SHADOW_OFFSET[1]),
    )
    shadow_alpha = shadow_alpha.filter(ImageFilter.GaussianBlur(SHADOW_BLUR))
    shadow = Image.new("RGBA", (CANVAS, CANVAS), (15, 23, 42, 0))
    shadow.putalpha(shadow_alpha)

    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(artwork, ((CANVAS - CONTENT) // 2, (CANVAS - CONTENT) // 2))
    return canvas


def png_bytes(image: Image.Image, size: int) -> bytes:
    from io import BytesIO

    output = BytesIO()
    image.resize((size, size), Image.Resampling.LANCZOS).save(
        output, format="PNG", optimize=True
    )
    return output.getvalue()


def write_icns(canvas: Image.Image, output: Path) -> None:
    chunks = []
    for icon_type, size in ICNS_TYPES:
        payload = png_bytes(canvas, size)
        chunks.append(icon_type.encode("ascii") + struct.pack(">I", len(payload) + 8) + payload)
    body = b"".join(chunks)
    output.write_bytes(b"icns" + struct.pack(">I", len(body) + 8) + body)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    root = Path(__file__).resolve().parents[2]
    parser.add_argument(
        "--source",
        type=Path,
        default=root / "data/icons/tyeditor-1024.png",
        help="1024px PNG artwork (default: data/icons/tyeditor-1024.png)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=root / "data/icons/tyeditor.icns",
        help="output .icns path (default: data/icons/tyeditor.icns)",
    )
    args = parser.parse_args()

    canvas = build_canvas(args.source)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    write_icns(canvas, args.output)
    print(f"wrote {args.output} ({args.output.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
