"""Prepare window-backdrop variants from a source wallpaper.

The source (a greyscale layered-forest illustration) has a near-white sky, which is
backwards for a dark UI. This produces three candidates so the choice can be made
by looking rather than arguing:

  raw      - resized only, to show why untreated art does not work
  night    - luminance crushed toward black and mapped to a cool duotone, so the
             sky reads as dark slate and the treeline goes near-black
  inverted - luminance inverted first, giving an almost-black sky and a pale
             treeline: maximum contrast, least natural

Everything is resized to 1024px wide because Roblox resamples uploads to 1024.

Usage: python gen_backdrop.py <source.jpg> [copy_dir]
"""

import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

WIDTH = 1024
REPO = Path(__file__).resolve().parent.parent
OUTDIR = REPO / "assets" / "backdrops"
OUTDIR.mkdir(parents=True, exist_ok=True)


def duotone(lum, dark, light):
    """Map 0..1 luminance onto a two-point colour ramp."""
    dark = np.array(dark, dtype=np.float64)
    light = np.array(light, dtype=np.float64)
    return dark[None, None, :] + lum[..., None] * (light - dark)[None, None, :]


def save(arr, name):
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), mode="RGB")
    path = OUTDIR / f"{name}.png"
    img.save(path, format="PNG", optimize=True)
    return path


src = Path(sys.argv[1])
im = Image.open(src).convert("L")
h = round(im.height * WIDTH / im.width)
im = im.resize((WIDTH, h), Image.LANCZOS)
lum = np.asarray(im, dtype=np.float64) / 255.0

written = []

# raw: greyscale, resized only
written.append(save(np.dstack([lum * 255] * 3), "raw"))

# night: crush toward black, then cool duotone. Sky ~ #2b3339, trees ~ #080b0d
night = np.clip(lum * 0.34 + 0.02, 0, 1)
written.append(save(duotone(night, (8, 11, 13), (108, 126, 138)), "night"))

# inverted: near-black sky, pale treeline
inv = np.clip((1.0 - lum) * 0.85 + 0.03, 0, 1)
written.append(save(duotone(inv, (9, 12, 14), (150, 168, 178)), "inverted"))

for p in written:
    print(f"{p.relative_to(REPO)}  {p.stat().st_size // 1024} KB")

if len(sys.argv) > 2:
    dest = Path(sys.argv[2])
    dest.mkdir(parents=True, exist_ok=True)
    for p in written:
        shutil.copy2(p, dest / f"chroma_bd_{p.name}")
    print(f"copied {len(written)} files to {dest}")
