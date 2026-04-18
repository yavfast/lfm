# Specification: Display Options  {#SP_DSP}

> **Code:** SP_DSP
> **Status:** active
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Concept:** [C_DSP](./display_options.concept.md)
> **Plan:** [PL_DSP](./display_options.plan.md)
> **Depends on specifications:** [SP_PLT](./platform_constraints.sp.md), [SP_SYS](./lfm_sys.sp.md), [SP_LFM](./lfm.sp.md), [SP_OPS](./file_operations.sp.md) (for `lfm_prompt`)

## 1. Data Structures  {#SP_DSP_01}

### 1.1. Panel state additions  {#SP_DSP_01_01}

Three new fields on the `Panel` record (see [SP_LFM_01](./lfm.sp.md) and [SP_OPS_01_01](./file_operations.sp.md#SP_OPS_01_01)):

| Field | Type | Domain | Default | Semantics |
|-------|------|--------|---------|-----------|
| `sort_by` | string | `"name"`, `"ext"`, `"size"`, `"date"` | `"name"` | Primary sort key. |
| `sort_desc` | boolean | — | `false` | `true` = descending, `false` = ascending. |
| `show_hidden` | boolean | — | `false` | Whether dotfile entries (names starting with `.`, excluding `..`) are displayed. |

**Invariants:**

- `sort_by` MUST always be one of the four allowed values. Any caller-provided invalid value is treated as `"name"`.
- Changing `sort_by` to a value *different* from the current one resets `sort_desc` to `false` (new fields always start ascending).
- Changing `sort_by` to the *same* value toggles `sort_desc`.
- Toggling `show_hidden` MUST trigger a `refresh_panels()` (re-fetch + re-sort + redraw).
- `sort_by` / `sort_desc` changes MUST NOT re-fetch from disk — they re-sort the existing `items` in place.

### 1.2. MenuItem  {#SP_DSP_01_02}

| Field | Type | Semantics |
|-------|------|-----------|
| `key` | string (1 char) | Single printable ASCII character the user presses to pick this item. |
| `text` | string | Human-readable label including current state snapshot (e.g., `"Sort: name↓"`). |

## 2. Module Contracts  {#SP_DSP_02}

### 2.1. `lfm_prompt.menu(label, items, layout) -> string | nil`  {#SP_DSP_02_01}

- **`label`**: short title (e.g., `"Display Options:"`). Drawn as prefix on the hints row.
- **`items`**: array of `MenuItem`.
- **`layout`**: `{ row, col, cols }`, identical to other prompt primitives.
- **Rendering form**: `<label>  (k1) <text1>  (k2) <text2>  …  Esc=cancel` on a single row, bright-white fg, black bg. Truncated with `~` when wider than `layout.cols`.
- **Input loop**: blocking. Accepts:
  - Any char matching an item's `key` → returns that key (lowercased if the stored key is lowercase).
  - `"escape"` → returns `nil`.
  - Any other input → ignored, loop continues.
- **Side effects**: none outside of drawing. Does NOT toggle tty state.
- **Tty assumption**: raw mode is already active (same as other prompt primitives).

### 2.2. `sort_comparator(sort_by, sort_desc) -> function(a, b) -> boolean`  {#SP_DSP_02_02}

Internal helper in `lfm.lua` (no new module needed). Returns a `table.sort` compatible predicate.

- **Pre-order invariants:** `..` first; directories before files; inside each group, primary by `sort_by` + tiebreaker by name-lower.
- **Per-mode semantics:**

| `sort_by` | Key function | Notes |
|-----------|-------------|-------|
| `"name"` | `name:lower()` | No tiebreaker needed (names are unique within a dir). |
| `"ext"`  | `(ext:lower(), name:lower())` | `ext` = substring after last `.` in name, treating a leading dot as part of the name (so `.hidden` → ext `""`, `.tar.gz` → ext `"gz"`). Case-insensitive compare. |
| `"size"` | `(tonumber(size) or 0, name:lower())` | For dirs, `size` is 0 — which means mixed-sizes sort shows dirs together regardless of sort direction. |
| `"date"` | `(tonumber(modified) or 0, name:lower())` | Epoch seconds. |

- **Descending** flips the primary comparison only. Tiebreaker (name-lower) is always ascending — keeps visual order stable even in desc mode when primary keys collide.

### 2.3. `filter_hidden(items, show_hidden) -> items`  {#SP_DSP_02_03}

Internal helper in `lfm.lua`.

- If `show_hidden == true`: returns `items` unchanged.
- If `show_hidden == false`: returns a new array excluding entries whose `name` starts with `.` *except* the literal `".."`.

### 2.4. Modified `refresh_panels`  {#SP_DSP_02_04}

`refresh_panels` is unchanged in signature but its internal use of `open_dir` must now:

1. Fetch items via `lfm_files.get_directory_items`.
2. Apply `filter_hidden` using `panel.show_hidden`.
3. Sort items using `sort_comparator(panel.sort_by, panel.sort_desc)`.
4. Selection and cursor restoration logic unchanged (works on the filtered list).

### 2.5. Modified `open_dir`  {#SP_DSP_02_05}

- Must respect `panel.show_hidden` and `panel.sort_by` / `panel.sort_desc`.
- Does NOT reset these fields when navigating into a directory. They persist across path changes within the same panel's lifetime.
- Changing directory DOES reset `panel.selected` (unchanged from SP_OPS_01_01).

## 3. Key Dispatch Extensions  {#SP_DSP_03}

### 3.1. New `get_key` token  {#SP_DSP_03_01}

| Token | Escape sequence | When fired |
|-------|-----------------|------------|
| `"options"` | `\27[20~` (F9) | Always |

### 3.2. F9 dispatch in `handle_navigation_key`  {#SP_DSP_03_02}

When `key == "options"`:

1. Open top-level menu (label `"Options:"`) with items:
   - `1`: `"Sort: " .. sort_label(panel)`
   - `2`: `"Hidden: " .. (panel.show_hidden and "on" or "off")`
   - `3`: `"Sync paths"`
2. If user picks `1`: open sort sub-menu (see 3.3).
3. If user picks `2`: flip `panel.show_hidden`, call `refresh_panels`.
4. If user picks `3`: copy active's `current_dir` to inactive panel and re-`open_dir` inactive (no-op when paths already match, but still refresh via the re-open). Menu closes.
5. If user presses Esc: close menu, no-op.

### 3.3. Sort sub-menu  {#SP_DSP_03_03}

Label: `"Sort by: "` prefix. Items:

| `key` | `text` | Action on selection |
|-------|--------|---------------------|
| `n` | `"name"` | `panel.sort_by = "name"` (toggle desc if same) |
| `e` | `"ext"` | `panel.sort_by = "ext"` (toggle desc if same) |
| `s` | `"size"` | `panel.sort_by = "size"` (toggle desc if same) |
| `d` | `"date"` | `panel.sort_by = "date"` (toggle desc if same) |
| `r` | `"reverse"` | `panel.sort_desc = not panel.sort_desc` |

Note: `lfm_prompt.menu` renders each item as `(<key>) <text>`, so the text field intentionally omits the mnemonic parens.

Label also shows current state as a suffix: `"current: <mode> <arrow>"` where arrow is `↑` for asc, `↓` for desc.

Behavior on selection: re-sort `panel.items` in place (no re-fetch), redraw. On Esc: re-open the top-level menu (menu-stack semantics).

### 3.4. `sort_label(panel)` helper  {#SP_DSP_03_04}

Returns `<mode><arrow>` where mode ∈ {`name`, `ext`, `size`, `date`} and arrow ∈ {`↑`, `↓`}.

## 4. Rendering Changes  {#SP_DSP_04}

### 4.1. Updated hints row  {#SP_DSP_04_01}

The hints bar shows only F-keys (per the "no printable / no modifier hotkeys in hints" directive from 2026-04-18):

```
F3:View F4:Edit F5:Copy F6:Move F7:Mkdir F8:Del F9:Opts F10:Quit
```

Truncate via `lfm_str.pad_string(hints, view_width, true)` so narrow terminals render a `~`-suffix instead of wrapping. Function-key modifiers (`Ins`, `Tab`, `^U`) and panel-level Alt+letter shortcuts are intentionally omitted from this bar — they're documented elsewhere, not hints material.

### 4.2. Panel rendering  {#SP_DSP_04_02}

No changes to `draw_panel_row`. Sort/filter changes manifest purely through `panel.items` being a different list.

## 5. Error Cases  {#SP_DSP_05}

| Scenario | Behavior |
|----------|----------|
| User presses a key not in the menu items table | Ignored; menu continues. |
| Lua 5.1 / 5.2 compatibility — `↑` / `↓` arrow glyphs | Using UTF-8 literals `\226\134\145` / `\226\134\147` — terminal must render UTF-8 (all modern consoles do, including BusyBox+musl). If terminal cannot, the arrow shows as replacement; not a functional issue. |
| Toggling hidden on a directory with only dotfiles | Result list is `[..]` only. Cursor lands on `..`. |
| Sort comparator receives items with missing fields (malformed) | `tonumber` coerces to `0`; sort remains deterministic; no crash. |
| F9 pressed while prompt is already open | Cannot happen — prompt captures all keys, F9 included. F9 is only dispatched from the panel loop. |
| F9 pressed when terminal widget has text | Intercepted by terminal input per existing gate in [SP_LFM dispatch](./lfm.sp.md). Consistent with F5-F8 behavior. |

## 6. Integration Scenarios  {#SP_DSP_06}

### 6.1. Sort by size descending, then by name  {#SP_DSP_06_01}

1. Panel1 starts: sort_by="name" asc, items sorted alphabetically.
2. F9 → `1` → Sort sub-menu.
3. Press `s` → sort_by="size", sort_desc=false. Items re-sorted: biggest file first within files group.
4. Press F9 → `1` → Sort sub-menu.
5. Press `s` again → sort_desc flips to true. Items re-sorted: smallest file first.
6. Press F9 → `1` → press `n` → sort_by="name", sort_desc=false. Alphabetic again.

### 6.2. Toggle hidden files  {#SP_DSP_06_02}

1. Panel1 lists 5 regular files; `.hidden` exists in dir but is not shown.
2. F9 → `2` → `show_hidden=true`, `refresh_panels()`. List now shows 6 entries.
3. F9 → `2` → `show_hidden=false`. List shows 5 entries again.
4. Cursor preservation: If cursor was on `.hidden` when toggled off, cursor falls back to `..`.

### 6.3. Independent per-panel settings  {#SP_DSP_06_03}

1. Panel1: sort_by=date desc, show_hidden=false.
2. Tab → Panel2.
3. Panel2: sort_by=name asc, show_hidden=false (defaults; not propagated from panel1).
4. F9 on Panel2 → change sort to size — only Panel2's display updates; Panel1 unchanged.

### 6.4. Esc navigation in sub-menu  {#SP_DSP_06_04}

1. F9 → top-level menu shows.
2. Press `1` → sort sub-menu shows.
3. Press Esc → top-level menu re-appears.
4. Press Esc → menu closes.

## 7. Verification Criteria  {#SP_DSP_07}

### 7.1. Unit-testable  {#SP_DSP_07_01}

- `sort_comparator` on synthetic item lists for each (mode, desc) combination. Directories-first invariant holds. Tiebreaker produces deterministic order.
- `filter_hidden` — `.git` filtered out when `show_hidden=false`; kept when true; `..` always kept.

### 7.2. Live-verifiable via agent-tui  {#SP_DSP_07_02}

- Fixture: mix of sizes, dates, extensions; at least one hidden file.
- Flow: F9 → 1 → size desc → verify order; F9 → 1 → r → verify flipped; F9 → 2 → verify dotfile appears; F9 → 2 → verify dotfile gone; Tab to panel2 → verify panel2's sort unchanged (still name asc).

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initial draft — companion of [C_DSP](./display_options.concept.md). |
| 2026-04-18 | Top-level menu renamed to "Options:". Added item 3 "Sync paths" (absorbs the deprecated `=` hotkey). |
