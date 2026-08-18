"""Build M3 widget mockups for the visual companion.

Draws the dropdown popup and the colorpicker at Chroma's real metrics: 19px rows,
110px control slot, 7px checkbox, 2px slider track, 12px Ubuntu body text, 1px
borders, no corner radius.

Usage: python gen_m3_mockup.py <out.html>
"""

import sys
from pathlib import Path

CSS = """
<style>
.w { --win:#0e1113; --body:#131618; --cont:#17191a; --line:#2e3234; --field:#111314;
  --fieldb:#3a3f41; --txt:#bec2c3; --dim:#787d7e; --br:#f2f4f4; --acc:#17b8a6;
  font-family:Ubuntu,Verdana,sans-serif; font-size:12px; color:var(--txt); }
.stage { background:#07090a; padding:22px; display:flex; gap:26px; justify-content:center;
  align-items:flex-start; }
.cont { background:var(--cont); border:1px solid var(--line); padding:5px 7px; width:270px; }
.ctitle { color:var(--br); margin:0 0 4px 1px; font-size:12px; }
.row { display:flex; align-items:center; justify-content:space-between; height:19px; }
.row .lbl { display:flex; align-items:center; gap:5px; white-space:nowrap; }
.q { display:inline-flex; align-items:center; justify-content:center; width:12px; height:12px;
  border:1px solid var(--fieldb); color:var(--dim); font-size:10px;
  font-family:"Courier New",monospace; }
.cb { width:7px; height:7px; background:#25292b; border:1px solid var(--fieldb); }
.cb.on { background:var(--acc); border-color:var(--acc); }
.field { background:var(--field); border:1px solid var(--fieldb); height:14px; width:110px;
  display:flex; align-items:center; justify-content:space-between; padding:0 4px;
  color:var(--txt); font-size:11px; }
.field s { text-decoration:none; color:var(--dim); font-size:8px; }
.sw { width:110px; height:14px; border:1px solid var(--fieldb); }

/* dropdown popup */
.pop { position:absolute; background:var(--win); border:1px solid var(--acc);
  width:110px; z-index:5; }
.pop div { padding:2px 5px; font-size:11px; color:var(--txt); }
.pop div.sel { background:rgba(23,184,166,.16); color:var(--acc); }
.pop div.hov { background:rgba(255,255,255,.05); }
.pop .multi { display:flex; align-items:center; gap:5px; }
.pop .multi i { width:7px; height:7px; border:1px solid var(--fieldb); flex:none; }
.pop .multi i.on { background:var(--acc); border-color:var(--acc); }
.rel { position:relative; }

/* colorpicker popup */
.cp { position:absolute; background:var(--win); border:1px solid var(--acc); padding:7px;
  width:176px; z-index:5; }
.sq { width:162px; height:96px; position:relative;
  background:linear-gradient(to top,#000,transparent),linear-gradient(to right,#fff,hsl(170,100%,50%)); }
.sq b { position:absolute; left:74%; top:26%; width:7px; height:7px; border:1px solid #fff;
  border-radius:50%; box-shadow:0 0 0 1px rgba(0,0,0,.6); }
.strip { width:162px; height:10px; margin-top:6px; position:relative; }
.hue { background:linear-gradient(to right,#f00,#ff0,#0f0,#0ff,#00f,#f0f,#f00); }
.alpha { background:linear-gradient(to right,transparent,hsl(170,80%,45%)),
  repeating-conic-gradient(#3a3f41 0% 25%,#22282a 0% 50%) 0/8px 8px; }
.strip b { position:absolute; top:-2px; width:2px; height:14px; background:#fff;
  box-shadow:0 0 0 1px rgba(0,0,0,.6); }
.cpin { display:flex; gap:5px; margin-top:7px; }
.cpin input { background:var(--field); border:1px solid var(--fieldb); color:var(--txt);
  font-family:inherit; font-size:11px; padding:1px 4px; width:100%; box-sizing:border-box; }
.cap { font-size:11px; color:#7d8fa1; line-height:1.55; }
.tag { color:var(--dim); font-size:11px; margin:0 0 6px; }
</style>
"""


def dropdown_panel(title, rows_html, popup_html, popup_top):
    return f"""
<div class="w rel">
  <div class="ctitle">{title}</div>
  <div class="cont">{rows_html}</div>
  <div class="pop" style="left:167px; top:{popup_top}px">{popup_html}</div>
</div>
"""


SINGLE_ROWS = """
      <div class="row"><span class="lbl">Enabled<span class="q">?</span></span><i class="cb on"></i></div>
      <div class="row"><span class="lbl">Hitbox</span><span class="field">Head <s>&#9660;</s></span></div>
      <div class="row"><span class="lbl">Wall check</span><i class="cb on"></i></div>
"""

MULTI_ROWS = """
      <div class="row"><span class="lbl">Enabled<span class="q">?</span></span><i class="cb on"></i></div>
      <div class="row"><span class="lbl">Hitboxes</span><span class="field">3 selected <s>&#9660;</s></span></div>
      <div class="row"><span class="lbl">Wall check</span><i class="cb on"></i></div>
"""

SINGLE_POP = """
      <div class="sel">Head</div>
      <div class="hov">Torso</div>
      <div>Pelvis</div>
      <div>Arms</div>
      <div>Legs</div>
"""

MULTI_POP = """
      <div class="multi"><i class="on"></i>Head</div>
      <div class="multi"><i class="on"></i>Torso</div>
      <div class="multi hov"><i></i>Pelvis</div>
      <div class="multi"><i class="on"></i>Arms</div>
      <div class="multi"><i></i>Legs</div>
"""

COLOR_ROWS = """
      <div class="row"><span class="lbl">Enabled<span class="q">?</span></span><i class="cb on"></i></div>
      <div class="row"><span class="lbl">Box colour</span><span class="sw" style="background:hsl(170,70%,42%)"></span></div>
      <div class="row"><span class="lbl">Filled</span><i class="cb"></i></div>
"""

COLOR_POP = """
      <div class="sq"><b></b></div>
      <div class="strip hue"><b style="left:47%"></b></div>
      <div class="strip alpha"><b style="left:78%"></b></div>
      <div class="cpin"><input value="#17B8A6"></div>
"""

html = f"""<h2>Dropdown popup and colorpicker</h2>
<p class="subtitle">Chroma's real metrics: 19px rows, 110px control slot, 12px Ubuntu, 1px borders, no radius. Popups are drawn where they would actually appear &mdash; in the overlay layer, aligned to the right edge of the control slot, directly under the row.</p>
{CSS}

<div class="mockup">
  <div class="mockup-header">Dropdown &mdash; single-select (left) and multi-select (right)</div>
  <div class="mockup-body stage" style="min-height:200px">
    {dropdown_panel("Aimbot", SINGLE_ROWS, SINGLE_POP, 43)}
    {dropdown_panel("Aimbot", MULTI_ROWS, MULTI_POP, 43)}
  </div>
</div>

<p class="cap"><b>Single-select</b> marks the current value with the accent and an accent-tinted row; clicking commits and closes. <b>Multi-select</b> gives every entry a 7px checkbox matching the toggle, stays open while you pick, and the closed field reads <code>3 selected</code>. Both scroll past roughly 8 entries.</p>

<div class="mockup">
  <div class="mockup-header">Colorpicker &mdash; HSV square, hue and alpha strips, hex field</div>
  <div class="mockup-body stage" style="min-height:230px">
    <div class="w rel">
      <div class="ctitle">Players</div>
      <div class="cont">{COLOR_ROWS}</div>
      <div class="cp" style="left:167px; top:43px">{COLOR_POP}</div>
    </div>
  </div>
</div>

<p class="cap">The closed state is a 110px swatch filling the control slot, which reads better at a glance than a small square with empty space beside it. The popup is 176px wide &mdash; wider than the control slot, so it aligns to the slot's right edge and extends left. The single field accepts hex or comma-separated RGB(A); the alpha strip only appears when <code>Alpha</code> is set.</p>

<p class="cap"><b>Worth deciding while you look:</b> whether the alpha strip should show a chequerboard behind it as drawn here &mdash; it is the honest way to show transparency, but it is the busiest element in an otherwise flat UI.</p>
"""

Path(sys.argv[1]).write_text(html, encoding="utf-8")
print(f"wrote {sys.argv[1]}")
