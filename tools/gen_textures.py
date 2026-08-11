"""Generate seamless greyscale tile candidates for the Chroma window backdrop.

Every tile is white-on-transparent so Roblox's ImageColor3 can tint it, and every
pattern is periodic by construction so ScaleType.Tile shows no seams.

Writes PNGs to assets/textures/ and an HTML preview (with the images inlined as
data URIs) to the path given as argv[1].
"""

import base64
import io
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SIZE = 96          # final tile resolution
SS = 4             # supersample factor for antialiasing
N = SIZE * SS
ACCENT = (23, 184, 166)

REPO = Path(__file__).resolve().parent.parent
OUTDIR = REPO / "assets" / "textures"
OUTDIR.mkdir(parents=True, exist_ok=True)


def coords():
    y, x = np.mgrid[0:N, 0:N].astype(np.float64)
    return x, y


def tileable_noise(cutoff, seed):
    """Low-pass filtered white noise. Periodic because the FFT basis is."""
    rng = np.random.default_rng(seed)
    white = rng.normal(size=(N // SS, N // SS))
    spec = np.fft.fft2(white)
    fy = np.fft.fftfreq(N // SS)[:, None]
    fx = np.fft.fftfreq(N // SS)[None, :]
    radius = np.sqrt(fx ** 2 + fy ** 2)
    spec[radius > cutoff] = 0
    out = np.real(np.fft.ifft2(spec))
    out -= out.min()
    if out.max() > 0:
        out /= out.max()
    return np.kron(out, np.ones((SS, SS)))


def line_mask(value, pitch, width):
    """Distance to the nearest multiple of pitch, wrapped -> antialiased lines."""
    d = np.mod(value, pitch)
    d = np.minimum(d, pitch - d)
    return np.clip(1.0 - d / width, 0.0, 1.0)


def p_hatch():
    x, y = coords()
    return line_mask(x + y, 10 * SS, 1.1 * SS) * 0.85


def p_crosshatch():
    x, y = coords()
    a = line_mask(x + y, 14 * SS, 1.0 * SS)
    b = line_mask(x - y, 14 * SS, 1.0 * SS)
    return np.maximum(a, b) * 0.8


def p_grid():
    x, y = coords()
    a = line_mask(x, 12 * SS, 1.0 * SS)
    b = line_mask(y, 12 * SS, 1.0 * SS)
    return np.maximum(a, b) * 0.75


def p_carbon():
    x, y = coords()
    cell = 12 * SS
    cx = np.mod(x, cell * 2) < cell
    cy = np.mod(y, cell * 2) < cell
    warp = np.where(cx ^ cy, np.mod(x, cell) / cell, np.mod(y, cell) / cell)
    weave = 0.35 + 0.65 * np.abs(np.sin(warp * np.pi))
    seam = np.maximum(line_mask(x, cell, 0.9 * SS), line_mask(y, cell, 0.9 * SS))
    return np.clip(weave * 0.55 + seam * 0.45, 0, 1) * 0.8


def p_dots():
    x, y = coords()
    pitch = 14 * SS
    row = np.floor(y / pitch)
    offset = np.where(np.mod(row, 2) == 0, 0.0, pitch / 2)
    dx = np.mod(x + offset, pitch) - pitch / 2
    dy = np.mod(y, pitch) - pitch / 2
    dist = np.sqrt(dx ** 2 + dy ** 2)
    return np.clip(1.0 - (dist - 1.4 * SS) / (1.1 * SS), 0, 1) * 0.85


def p_grain():
    n = tileable_noise(0.34, 7)
    return np.clip((n - 0.38) * 1.9, 0, 1) * 0.9


def p_contour():
    n = tileable_noise(0.075, 21)
    bands = np.abs(np.sin(n * np.pi * 7.0))
    return np.clip(1.0 - bands / 0.22, 0, 1) * 0.85


def p_streaks():
    x, y = coords()
    n = tileable_noise(0.11, 42)
    profile = n[0:1, :].repeat(N, axis=0)
    fine = line_mask(x, 6 * SS, 0.8 * SS) * 0.35
    return np.clip(profile * 0.85 + fine, 0, 1) * 0.7


PATTERNS = [
    ("hatch", "Diagonal hatch", "Single-direction 45 degree lines, 10px pitch. The most neutral option and the closest relative of Bracket's tile without being it.", p_hatch),
    ("crosshatch", "Crosshatch", "Both diagonals at a wider 14px pitch. Reads as woven mesh; busier than hatch but more interesting at low opacity.", p_crosshatch),
    ("grid", "Fine grid", "Orthogonal 1px lines at 12px pitch. Technical and quiet, closest in spirit to gamesense's flatness.", p_grid),
    ("carbon", "Carbon weave", "Alternating over-under weave cells. The classic cheat-UI texture; has real depth but is the busiest here.", p_carbon),
    ("dots", "Halftone dots", "Staggered dot rows, 14px pitch. Very clean, and the only pattern with no lines at all, so it never fights the 1px strokes elsewhere in the UI.", p_dots),
    ("grain", "Film grain", "Tileable filtered noise. Organic rather than geometric; gives the chrome material without imposing a direction.", p_grain),
    ("contour", "Topographic contours", "Contour bands from low-frequency noise. The most distinctive of the set, and the most likely to look dated in a year.", p_contour),
    ("streaks", "Prismatic streaks", "Vertical bands of varying width, on-theme for the name. Directional, so it emphasises the window's height.", p_streaks),
]


def to_png_bytes(alpha, rgb):
    small = Image.fromarray((alpha * 255).astype(np.uint8), mode="L").resize(
        (SIZE, SIZE), Image.LANCZOS
    )
    a = np.array(small)
    img = np.zeros((SIZE, SIZE, 4), dtype=np.uint8)
    img[..., 0] = rgb[0]
    img[..., 1] = rgb[1]
    img[..., 2] = rgb[2]
    img[..., 3] = a
    buf = io.BytesIO()
    Image.fromarray(img, mode="RGBA").save(buf, format="PNG", optimize=True)
    return buf.getvalue()


cards = []
for key, title, blurb, fn in PATTERNS:
    alpha = np.clip(fn(), 0, 1)

    white_png = to_png_bytes(alpha, (255, 255, 255))
    (OUTDIR / f"{key}.png").write_bytes(white_png)

    tinted_png = to_png_bytes(alpha, ACCENT)
    b64_white = base64.b64encode(white_png).decode()
    b64_tint = base64.b64encode(tinted_png).decode()

    cards.append(f"""
  <div class="card" data-choice="{key}" onclick="toggleSelect(this)">
    <div class="card-image tex-row">
      <div class="zoom" style="background-image:url(data:image/png;base64,{b64_white})"></div>
      <div class="win">
        <div class="tile" style="background-image:url(data:image/png;base64,{b64_tint})"></div>
        <div class="hair"></div>
        <div class="wtitle">{title}</div>
        <div class="rail"></div>
        <div class="box">
          <div class="r"><span>Enabled</span><i class="on"></i></div>
          <div class="r"><span>Silent aim</span><i></i></div>
          <div class="r"><span>Wall check</span><i class="on"></i></div>
          <div class="r"><span>Auto fire</span><i></i></div>
          <div class="r"><span>Randomize</span><i class="on"></i></div>
        </div>
      </div>
    </div>
    <div class="card-body">
      <h3>{title}</h3>
      <p>{blurb}</p>
      <p class="cap">assets/textures/{key}.png &mdash; {SIZE}x{SIZE}, white on transparent</p>
    </div>
  </div>""")

html = f"""<h2>Seamless backdrop tile candidates</h2>
<p class="subtitle">Left of each card: the raw tile at 3x so you can see the pattern. Right: the same tile tinted to the accent, tiled at 74px, at the real opacity, behind a container set to the 0.15 transparency you picked. All are white-on-transparent and periodic, so no seams and the theme can recolour them.</p>

<style>
.tex-row {{ display:flex; gap:16px; align-items:center; background:#0b0d0e; padding:16px; }}
.zoom {{ flex:0 0 108px; height:108px; background-color:#15181a; background-repeat:repeat;
  background-size:54px 54px; border:1px solid #262b2d; }}
.win {{ position:relative; width:250px; height:150px; background:#1e2123; overflow:hidden;
  box-shadow:0 0 0 1px #17b8a6, 0 0 12px rgba(23,184,166,.22);
  font-family:Verdana,Tahoma,sans-serif; font-size:9px; color:#b6babb; flex:0 0 250px; }}
.tile {{ position:absolute; inset:0; background-repeat:repeat; background-size:74px 74px; opacity:.5; }}
.hair {{ position:absolute; top:0; left:0; right:0; height:2px; z-index:5;
  background:linear-gradient(90deg,#d8d84a,#7ecb7a 45%,#17b8a6); }}
.wtitle {{ position:absolute; top:5px; left:8px; color:#eef0f0; z-index:4; }}
.rail {{ position:absolute; top:26px; left:0; bottom:0; width:26px; background:rgba(20,22,23,.75); z-index:3; }}
.box {{ position:absolute; top:32px; left:34px; right:10px; bottom:10px; z-index:4;
  background:rgba(23,25,26,.85); border:1px solid #2e3234; padding:5px 7px; }}
.box .r {{ display:flex; align-items:center; justify-content:space-between; padding:1.5px 0; }}
.box i {{ width:6px; height:6px; background:#25292b; border:1px solid #3a3f41; }}
.box i.on {{ background:#17b8a6; border-color:#17b8a6; }}
.cap {{ font-size:10px; color:#7d8fa1; margin-top:6px; line-height:1.5; }}
</style>

<div class="cards">{''.join(cards)}</div>

<p class="cap">These are generated by <code>tools/gen_textures.py</code>, so pitch, line weight and contrast are all parameters &mdash; if one is close but too busy or too faint, say so and I will re-run it rather than start over. Once you pick, the PNG gets uploaded to Roblox as a decal and its asset id is baked into the theme defaults, with <code>Backdrop.Image</code> left overridable so any script can supply its own.</p>
"""

Path(sys.argv[1]).write_text(html, encoding="utf-8")
print(f"wrote {len(PATTERNS)} tiles to {OUTDIR}")
print(f"wrote preview to {sys.argv[1]}")
