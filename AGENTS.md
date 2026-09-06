# Chroma

A UI library for Roblox executor scripts, styled after gamesense. Consumers load one generated file.

Design notes are kept locally rather than in the repo. Where a decision was reached by measurement
or cost a debugging cycle, the reason is in a comment next to the code — those comments are the
record, so don't strip them.

## Credits

The Lucide icons the rail can render (`Icon = "settings"` and friends) are served as Roblox image
assets by [icons.rest](https://www.icons.rest), a community project that pre-uploaded every Lucide
glyph. Chroma bakes that project's name-to-asset-id mapping into `src/core/lucide_assets.lua`;
regenerate with `python tools/gen_lucide_assets.py` when the upstream mapping changes.

## Invariants

1. **`src/` is bundled, never loaded directly.** `build/build.py` wraps each module as
   `function(require) ... end` inside `dist/main.lua`. Per-file directives such as `--!strict` would
   land mid-file in the bundle and be inert, so they are not used; run analysis against `src/` if you
   want type checking.
2. **`dist/main.lua` is committed and must match a fresh build.** Consumers fetch it directly.
   Rebuild before committing, and confirm `git status` is clean afterwards.
3. **Two dialects.** Modules whose logic touches no Roblox Instance are written in the
   Lua 5.4 ∩ Luau intersection and unit tested locally: no `+=`, no bitwise operators, no `goto`.
   Instance-touching modules never run under 5.4 and may use Luau freely. A file may hold both
   halves — `column.lua`, `tooltip.lua`, `cursor.lua`, `backdrop.lua` and `slider.lua` all do — with
   the pure half first.
4. **Never call `game:GetService` at module scope.** The test harness `require`s these files and
   `game` does not exist under 5.4. Declare `local X` unassigned and assign inside the constructor:
   `X = X or game:GetService("X")`.
5. **Everything created registers with `root:keep`**, or is a descendant of something that did.
   `Unload()` walks one list. Register cleanup once per object, never once per event — a `keep` call
   inside a hot path grows the teardown list forever.
6. **`task.delay` cannot be cancelled.** Any deferred callback must test `root:isAlive()` before
   touching anything.
7. **`AbsolutePosition` is screen space; `Position` is parent space.** With `IgnoreGuiInset = true`
   they differ by `GuiService:GetGuiInset()`. Use `root:mouseInGuiSpace()` and
   `root:toLayerSpace(x, y, layer)` rather than converting by hand. This single mismatch caused four
   separate bugs before the helpers existed.
8. **`AbsoluteSize` is `(0, 0)` until an instance has rendered once.** Anything sized or positioned
   from it must recompute on `GetPropertyChangedSignal("AbsoluteSize")`, not read it once at
   construction.
9. **Widgets contain no layout code.** A widget is handed `row.control` and renders into it. Row
   geometry, height and the full-row click affordance belong to `row.lua`, reached through
   `setHeight` and `onActivated`.
10. **`widgets/init.lua` is the only place a widget is registered.** `container.lua` generates one
    method per entry and has no per-widget knowledge; adding a widget is one line plus one file.
11. **Consumer callbacks go through `safecall`; Chroma's own errors do not.** A consuming script's
    broken callback must never take the menu down. An internal error is a bug and must surface.

## Conventions

- **camelCase** for locals, fields and functions; **PascalCase** for module tables, classes and the
  public API surface (`Root:Unload`, `Window:Page`, `Toggle:Set`). Private fields carry a leading
  underscore.
- Four-space indentation, no tabs.
- Comments record **why**, never what, and are kept where a decision is non-obvious or was reached
  by measurement — the coordinate-space and `AbsoluteSize` traps above each cost a debugging cycle
  before the comment existed. Do not strip them.
- Section dividers use `--== name ==--`.

## Verification

- `lua tests/run.lua` — unit tests for every pure module. Must be green before committing.
- `python build/build.py --install` — builds, and copies the bundle and dev harness into the
  Potassium workspace.
- In-game: `dofile("chroma_dev.lua")` through the Roblox MCP, driven by `dev/harness.lua`.
  Instance behaviour is verified here, not by stubbing the Instance API.
- Announce in-game tests before running them and wait, since the user cannot read messages while
  in-game. One probe per go.
