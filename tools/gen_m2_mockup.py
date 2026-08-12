"""Build M2 layout mockups for the visual companion.

Embeds the real backdrop PNG as a data URI so the chrome is judged in context
rather than against a flat colour. Renders the actual M1 metrics: 24px title bar,
4px gap, 28px rail, 19px row pitch, 7px checkbox, 2px slider track.

Usage: python gen_m2_mockup.py <which> <out.html>
  which = subtabs | headers
"""

import base64
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
BACKDROP = REPO / "assets" / "backdrops" / "night.png"

b64 = base64.b64encode(BACKDROP.read_bytes()).decode()
BG = f"data:image/png;base64,{b64}"

CSS = """
<style>
.w { --win:#0e1113; --body:#131618; --bar:#1a1e21; --cont:#17191a; --line:#2e3234;
  --field:#111314; --fieldb:#3a3f41; --txt:#bec2c3; --dim:#787d7e; --br:#f2f4f4;
  --acc:#17b8a6; --acc2:#a8d84a;
  width:520px; background:var(--win); font-family:Ubuntu,Verdana,sans-serif;
  font-size:12px; color:var(--txt); position:relative; box-shadow:0 12px 40px rgba(0,0,0,.6); }
.w-bar { height:24px; background:rgba(26,30,33,.65); position:relative;
  display:flex; align-items:center; padding:0 8px; color:var(--br); font-size:12px; }
.w-bar::before, .w-bar::after { content:""; position:absolute; left:0; right:0; height:2px;
  background:linear-gradient(90deg,var(--acc),var(--acc2)); }
.w-bar::before { top:0; } .w-bar::after { bottom:0; }
.w-gap { height:4px; }
.w-body { position:relative; height:236px; overflow:hidden;
  background:var(--body) url(BGURL) no-repeat bottom center; background-size:cover;
  border:1px solid var(--acc); box-sizing:border-box; }
.w-rail { position:absolute; top:0; left:0; bottom:0; width:28px;
  background:rgba(20,22,23,.88); z-index:5; padding-top:8px; }
.w-rail i { display:block; width:10px; height:10px; margin:0 auto 7px;
  background:#686e70; }
.w-rail i.on { background:var(--acc); }
.w-main { margin-left:28px; height:100%; display:flex; flex-direction:column; }
.w-cols { display:flex; gap:8px; padding:8px; flex:1; align-items:flex-start; }
.w-col { flex:1; display:flex; flex-direction:column; gap:8px; min-width:0; }
.cont { background:rgba(23,25,26,.85); border:1px solid var(--line); }
.cont-b { padding:5px 7px; }
.row { display:flex; align-items:center; justify-content:space-between; height:19px; }
.row span { white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
.cb { width:7px; height:7px; background:#25292b; border:1px solid var(--fieldb); flex:none; }
.cb.on { background:var(--acc); border-color:var(--acc); }
.sl { width:74px; height:2px; background:var(--fieldb); position:relative; flex:none; }
.sl u { position:absolute; inset:0 auto 0 0; background:var(--acc); }
.sl b { position:absolute; top:-3px; width:2px; height:8px; background:var(--acc); }
.val { color:var(--dim); font-size:11px; margin-left:6px; }
.q { display:inline-flex; align-items:center; justify-content:center; width:11px; height:11px;
  border:1px solid var(--fieldb); color:var(--dim); font-size:9px; margin-left:5px; flex:none; }

/* ---- sub-tab treatments ---- */
.st { display:flex; gap:14px; padding:6px 8px 0; }
.st div { color:var(--dim); padding-bottom:5px; cursor:default; }
.st div.on { color:var(--br); }

.st-underline div.on { border-bottom:2px solid var(--acc); }
.st-underline { border-bottom:1px solid var(--line); }

.st-block { gap:2px; padding:5px 6px 5px; border-bottom:1px solid var(--line); }
.st-block div { padding:3px 9px; background:rgba(255,255,255,.03); }
.st-block div.on { background:rgba(23,184,166,.16); color:var(--br);
  box-shadow:inset 0 -2px 0 var(--acc); }

.st-text { border-bottom:1px solid var(--line); }
.st-text div.on { color:var(--acc); }

.cap { font-size:11px; color:#7d8fa1; line-height:1.55; }
.hdr-out { color:var(--br); font-size:12px; margin:0 0 4px 1px; }
.hdr-in { padding:4px 7px 4px; color:var(--br); border-bottom:1px solid var(--line);
  background:rgba(255,255,255,.03); }
.hdr-acc { padding:4px 7px 4px; color:var(--br);
  border-bottom:1px solid var(--line); box-shadow:inset 2px 0 0 var(--acc); }
</style>
""".replace("BGURL", BG)


def rows(kind="mix"):
    return """
      <div class="row"><span>Enabled</span><i class="cb on"></i></div>
      <div class="row"><span>Silent aim<i class="q">?</i></span><i class="cb"></i></div>
      <div class="row"><span>Field of view</span>
        <span style="display:flex;align-items:center">
          <span class="sl"><u style="width:34%"></u><b style="left:33%"></b></span>
          <span class="val">20&deg;</span></span></div>
      <div class="row"><span>Wall check</span><i class="cb on"></i></div>
"""


def window(subtab_class, header_style="out", tabs=("General", "Weapons", "Anti-aim")):
    st = "".join(
        f'<div class="{"on" if i == 0 else ""}">{t}</div>' for i, t in enumerate(tabs)
    )

    def container(title, body):
        if header_style == "out":
            return f'<div><div class="hdr-out">{title}</div><div class="cont"><div class="cont-b">{body}</div></div></div>'
        if header_style == "in":
            return f'<div class="cont"><div class="hdr-in">{title}</div><div class="cont-b">{body}</div></div>'
        return f'<div class="cont"><div class="hdr-acc">{title}</div><div class="cont-b">{body}</div></div>'

    return f"""
<div class="w">
  <div class="w-bar">CHROMA</div>
  <div class="w-gap"></div>
  <div class="w-body">
    <div class="w-rail"><i class="on"></i><i></i><i></i><i></i><i></i></div>
    <div class="w-main">
      <div class="st {subtab_class}">{st}</div>
      <div class="w-cols">
        <div class="w-col">{container("Aimbot", rows())}</div>
        <div class="w-col">{container("Smoothing", rows())}</div>
      </div>
    </div>
  </div>
</div>
"""


def subtabs_page():
    return f"""<h2>Sub-tab styling</h2>
<p class="subtitle">Real M1 metrics: 24px title bar, 4px gap, 28px rail, 19px row pitch, 7px checkbox, 2px slider track. The sub-tab row sits inside the content area, right of the rail and above the columns.</p>
{CSS}
<div class="cards">
  <div class="card" data-choice="underline" onclick="toggleSelect(this)">
    <div class="card-image" style="padding:18px;background:#07090a;display:flex;justify-content:center">
      {window("st-underline")}
    </div>
    <div class="card-body"><h3>A &mdash; Underline the active tab</h3>
      <p>Text row with a 2px accent underline under the active item, and a 1px rule under the whole row.</p>
      <p class="cap">Quietest of the three, and the underline reuses the accent so it cycles with the RGB. Costs 12px of vertical space.</p></div>
  </div>
  <div class="card" data-choice="block" onclick="toggleSelect(this)">
    <div class="card-image" style="padding:18px;background:#07090a;display:flex;justify-content:center">
      {window("st-block")}
    </div>
    <div class="card-body"><h3>B &mdash; Filled block</h3>
      <p>Each tab is a shallow block; the active one gets an accent-tinted fill and an inset accent edge.</p>
      <p class="cap">Most obvious hit target, and reads as clickable before you hover it. Heaviest visually &mdash; it competes with the container headers below.</p></div>
  </div>
  <div class="card" data-choice="text" onclick="toggleSelect(this)">
    <div class="card-image" style="padding:18px;background:#07090a;display:flex;justify-content:center">
      {window("st-text")}
    </div>
    <div class="card-body"><h3>C &mdash; Accent text only</h3>
      <p>No underline, no fill. The active tab is simply accent-coloured; inactive are dim.</p>
      <p class="cap">Lightest and the least vertical space. Weakest affordance &mdash; nothing says "these are clickable", and when the accent cycles into a dark hue the active tab loses contrast against the backdrop.</p></div>
  </div>
</div>
<p class="cap">All three assume tabs are optional: a page with no <code>:Tab()</code> call has no row at all and its columns start 6px higher.</p>
"""


def headers_page():
    return f"""<h2>Container headers</h2>
<p class="subtitle">Same window, same rows, three ways of titling a container. Sub-tabs are shown underlined in all three so they are not part of the comparison.</p>
{CSS}
<div class="cards">
  <div class="card" data-choice="out" onclick="toggleSelect(this)">
    <div class="card-image" style="padding:18px;background:#07090a;display:flex;justify-content:center">
      {window("st-underline", "out")}
    </div>
    <div class="card-body"><h3>A &mdash; Title outside the box</h3>
      <p>The label sits above the bordered box, on the backdrop. This is what gamesense does.</p>
      <p class="cap">Cleanest separation and the box stays a pure content area. But the title sits on the forest, so its legibility depends on what is behind it.</p></div>
  </div>
  <div class="card" data-choice="in" onclick="toggleSelect(this)">
    <div class="card-image" style="padding:18px;background:#07090a;display:flex;justify-content:center">
      {window("st-underline", "in")}
    </div>
    <div class="card-body"><h3>B &mdash; Title inside, on a divider</h3>
      <p>The title is the first band inside the box, slightly lighter, with a 1px rule under it.</p>
      <p class="cap">Always legible because it sits on the container fill, and it makes the container feel like one object. Costs ~20px of container height per section.</p></div>
  </div>
  <div class="card" data-choice="acc" onclick="toggleSelect(this)">
    <div class="card-image" style="padding:18px;background:#07090a;display:flex;justify-content:center">
      {window("st-underline", "acc")}
    </div>
    <div class="card-body"><h3>C &mdash; Title inside with an accent edge</h3>
      <p>As B, plus a 2px accent bar down the left of the header band.</p>
      <p class="cap">Ties sections to the accent and gives the eye an anchor when scanning a tall column. Risks looking busy once a column holds five or six containers.</p></div>
  </div>
</div>
"""


which = sys.argv[1]
out = Path(sys.argv[2])
out.write_text(subtabs_page() if which == "subtabs" else headers_page(), encoding="utf-8")
print(f"wrote {which} -> {out}")
