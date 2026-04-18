# Options — Sort + Hidden Files  {#C_DSP}

> **Code:** C_DSP
> **Status:** active
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Depends on:** [C_PLT](./platform_constraints.concept.md), [C_LFM](./lfm.concept.md), [C_FIL](./lfm_files.concept.md), [C_OPS](./file_operations.concept.md) (reuses `lfm_prompt`)
> **Used by:** —
> **Specification:** [SP_DSP](./display_options.sp.md)
> **Plan:** [PL_DSP](./display_options.plan.md)
>
> Per-panel display controls: sort mode (name / ext / size / date, asc/desc) and toggle of hidden files. Accessed through a single menu entry point (F9) designed to be extended with more options over time.

## 1. Philosophy  {#C_DSP_01}

### 1.1. Core Principle  {#C_DSP_01_01}

Rather than dedicating a keyboard shortcut per display attribute (MC-style `Ctrl+F3..F6` + `Ctrl+H` + `Ctrl+.`), LFM funnels all display settings through **one entry key** (`F9`) into a small navigable menu. Trade-offs:

- **+** Portable across terminals — no reliance on non-standard `Ctrl+F-key` escape sequences (many IoT serial consoles don't emit them).
- **+** Discoverable — the menu renders the current state (`Sort: name↓`, `Hidden: off`) so users don't need to memorize bindings.
- **+** Extensible — adding a future `Filter`, `Color theme`, or `Panel layout` option is a one-liner in the menu-items table, no new hotkey.
- **−** One extra keystroke per change. Acceptable on IoT where display-settings changes are infrequent.

### 1.2. Design Constraints  {#C_DSP_01_02}

- **Per-panel state.** Each of the two panels keeps independent `sort_by`, `sort_desc`, `show_hidden`. Tab between panels does not propagate settings.
- **No persistence across sessions.** Settings reset on launch. Persisting to `~/.lfm/state` is a separate roadmap item ([R-NAV-03](./roadmap.plan.md#task-r-nav-03)).
- **Directories always first.** Sort modes apply *within* the file-vs-dir partition. `..` is always the first row.
- **Blocking menu.** While the menu is open, LFM input is captured by the menu loop. No async / background rendering.
- **Fork budget.** Toggling hidden re-fetches the directory (one `stat` fork); toggling sort is pure Lua (zero forks).

### 1.3. Scope boundary  {#C_DSP_01_03}

**IN SCOPE:**

- **C1** — sort by name / extension / size / modified-date, independently asc or desc.
- **C2** — toggle display of dotfile entries.
- **A3 (relocated)** — "Sync paths" item: copies the active panel's path to the inactive panel. Originally bound to `=` key; moved into this menu to honor the "no printable-character hotkeys" principle.
- Two-level menu architecture: `F9` opens the top-level "Options" menu, which dispatches to an immediate action or a sub-menu.
- New reusable primitive `lfm_prompt.menu(label, items, layout) → key | nil`.

**OUT OF SCOPE** (future promotion):

- **C3** — glob-mask filter (roadmap P2; needs a pattern prompt + persistent filter-state per panel).
- **C4** — git status column (roadmap P2; requires `git` which is not in BusyBox and typically absent on IoT deploys — per user directive, skipped entirely).
- Config file with default sort mode (roadmap [R-CFG-01](./roadmap.plan.md#task-r-cfg-01)).
- Per-extension sort (e.g. by MIME type) — YAGNI.

## 2. Domain Model  {#C_DSP_02}

### 2.1. Key Entities  {#C_DSP_02_01}

- **SortMode** — one of `"name"`, `"ext"`, `"size"`, `"date"`. Default `"name"`.
- **SortDirection** — boolean `sort_desc` (true = descending). Default `false` = ascending.
- **HiddenFlag** — boolean `show_hidden`. Default `false`.
- **MenuItem** — `{ key, text }`. Rendered as `(<key>) <text>` in a one-line overlay.

### 2.2. Data Flows  {#C_DSP_02_02}

```
F9
  ├── render top-level menu ("Options")
  ├── read one key:
  │     1 → open Sort sub-menu
  │     2 → toggle show_hidden, refresh_panels(), close
  │     3 → sync inactive panel to active's path, refresh, close
  │     Esc → close
  └── close overlay, redraw file manager

Sort sub-menu
  ├── render "(n)ame (e)xt (s)ize (d)ate (r)everse  current: <mode> <dir>"
  ├── read one key:
  │     n/e/s/d → set sort_by (reset sort_desc if different field)
  │     r → flip sort_desc
  │     Esc → back to Options (re-open)
  └── re-sort items in place, close, redraw
```

## 3. Mechanisms  {#C_DSP_03}

### 3.1. Sort comparator  {#C_DSP_03_01}

Single comparator closure built from `(sort_by, sort_desc)`. Stable partitioning: directories first regardless of mode, `..` before any directory.

Pseudo-code:

    return function(a, b)
        if a.name == ".." then return true end
        if b.name == ".." then return false end
        if a.is_dir ~= b.is_dir then return a.is_dir end  -- dirs first
        local cmp = compare(a, b, sort_by)               -- mode-specific
        if sort_desc then cmp = -cmp end
        return cmp < 0
    end

### 3.2. Mode-specific comparison  {#C_DSP_03_02}

| Mode | Primary key | Tiebreaker |
|------|-------------|------------|
| `name` | `name:lower()` lexical | none (names within a dir are unique) |
| `ext`  | extension (after last `.` in name; files without a dot → empty string) | name |
| `size` | numeric `size` | name |
| `date` | numeric `modified` timestamp | name |

Tiebreaker guarantees a deterministic order even when primary keys collide (two files with same size etc.), keeping the display stable across Ctrl+R.

### 3.3. Hidden-file filtering  {#C_DSP_03_03}

Applied at the `get_directory_items` result: after `get_directory_items` returns, LFM filters entries whose `name` starts with `.` (except the synthetic `..`) when `show_hidden == false`. No shell-glob change — the glob still fetches `.` entries; filtering happens in Lua.

Rationale: simpler invariant (one glob form), and the BusyBox `stat -c "... " path/* path/.*` form already returns dotfiles regardless.

### 3.4. Menu primitive  {#C_DSP_03_04}

`lfm_prompt.menu(label, items, layout) -> key | nil`:

- **`label`** — prompt title (e.g., `"Options"`).
- **`items`** — array of `{ key, text }`.
- **Render**: one line at `layout.row`. `<label>: (k1) text1  (k2) text2  …  Esc=cancel`. Truncate tail with `~` if width exceeded.
- **Loop**: read keys; accept `ch` if any item's `key == ch`; return `ch`. Return `nil` on `Escape`. Ignore other keys.
- **Unicode**: single-byte ASCII keys only; digits and lowercase letters. Good enough for menus.

### 3.5. Edge Cases  {#C_DSP_03_05}

- **Empty directory** — sort on empty items list is a no-op; no special case.
- **Single item (`..` only)** — also no-op.
- **Toggle hidden when cursor is on a dotfile** — dotfile vanishes. Cursor-by-name restore in `refresh_panels` fails → cursor resets to index 1. Acceptable.
- **Sort by size / date when all items have identical values** — tiebreak by name keeps it deterministic.
- **Esc in sub-menu** — returns to top-level menu (re-opens it). Consistent with a "menu stack" mental model.
- **Non-matching keys in menu** — ignored. No beep, no error. User tries again or hits Esc.

## 4. Integration Points  {#C_DSP_04}

### 4.1. Dependencies  {#C_DSP_04_01}

- **`lfm_prompt`** — extended with `menu()`.
- **`lfm_sys`** — `get_key` extended for F9.
- **`lfm_files`** — no change; comparator consumes Item fields directly.
- **`lfm.lua`** — new panel fields; new dispatch arm for F9; sort invocation uses panel-specific comparator; hidden filter applied post-fetch.

### 4.2. Modified Panel schema  {#C_DSP_04_02}

Add three fields (see [SP_DSP_01_01](./display_options.sp.md#SP_DSP_01_01)):

- `sort_by` (string) = `"name"` by default.
- `sort_desc` (boolean) = `false`.
- `show_hidden` (boolean) = `false`.

### 4.3. Public API changes  {#C_DSP_04_03}

None outside the module. All changes are internal to `lfm.lua` and `lfm_prompt.lua`.

## 5. Non-Goals  {#C_DSP_05}

- **Not a general faceted-search UI.** Menu is a simple dispatch; no multi-select, no type-ahead.
- **Not a config subsystem.** Defaults are hard-coded; config-file integration is a future feature.
- **Not a sort-stability guarantor across FS mtime precision.** We use whatever the OS reports; second-resolution ties fall to name.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initial draft — Area C slice (C1 + C2). C3/C4 deferred per roadmap / platform constraints. |
| 2026-04-18 | Menu renamed from "Display Options" to "Options". Added item 3 "Sync paths" (relocated from the deprecated `=` hotkey). |
