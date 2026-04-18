# File Manager Entry Point — Specification  {#SP_LFM}

> **Code:** SP_LFM
> **Status:** active
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Concept:** [C_LFM](./lfm.concept.md)
> **Depends on specs:** [SP_SYS](./lfm_sys.sp.md), [SP_FIL](./lfm_files.sp.md), [SP_SCR](./lfm_scr.sp.md), [SP_VIW](./lfm_view.sp.md), [SP_STR](./lfm_str.sp.md), [SP_TRM](./lfm_terminal.sp.md)
> **Used by specs:** —
> **Plan:** [lfm.plan.md](./lfm.plan.md)

## 01. Data Structures  {#SP_LFM_01}

### 01_01. Panel  {#SP_LFM_01_01}

Fields:
| Field | Type | Default | Constraints | Description |
|-------|------|---------|-------------|-------------|
| current_dir | string | `"."` | — | Panel's CWD (relative or absolute) |
| absolute_path | string | from `get_absolute_path` | absolute | Canonical path, used in header |
| selected_item | integer | 1 | `1 ≤ selected_item ≤ #items` | Currently highlighted row |
| scroll_offset | integer | 0 | `0 ≤ scroll_offset` | First visible row index - 1 |
| items | Item[] | — | — | Contents (see [SP_FIL_01_01](./lfm_files.sp.md#SP_FIL_01_01)) |
| view_width | integer | computed | ≥ 1 | Assigned each frame from screen width |
| view_height | integer | computed | ≥ 0 | Assigned each frame from screen height |

Invariants:
- `scroll_offset ≤ max(0, #items - view_height)`.
- `selected_item` always within `[1, #items]`.
- `items[1]` is `".."` for non-root directories.

### 01_02. ScreenLayout  {#SP_LFM_01_02}

| Field | Type | Rule |
|-------|------|------|
| terminal_height_percent | integer | 30 (constant) |
| terminal_height | integer | `max(5, floor(height * 30 / 100))` |
| main_height | integer | `height - terminal_height - 2 (hints)` |
| terminal_start_row | integer | `main_height + 1` |

### 01_03. Item sort order  {#SP_LFM_01_03}

Lexicographic comparator:
1. `".."` always first.
2. Directories before files.
3. Case-insensitive name ascending (`name:lower() < name:lower()`).

## 02. Contracts  {#SP_LFM_02}

### 02_01. sort_items  {#SP_LFM_02_01}

Input: `items` (Item[]). Output: same array, sorted in place per [SP_LFM_01_03](#SP_LFM_01_03).

### 02_02. update_scroll(panel)  {#SP_LFM_02_02}

Clamps `scroll_offset` so that `selected_item` remains within the visible window `[scroll_offset + 1, scroll_offset + view_height]`, and clamps it to `≥ 0`.

### 02_03. open_dir(panel, target_path, prev_dir?)  {#SP_LFM_02_03}

Input:
| Parameter | Type | Required | Constraints |
|-----------|------|----------|-------------|
| panel | Panel | yes | — |
| target_path | string | yes | path to navigate into; `""` is treated as `"/"` |
| prev_dir | string \| nil | no | the directory being navigated **away from**; used to restore cursor position on `..` navigation |

Side effects:
- `lfm_files.clear_path_cache()`.
- Reloads items, sorts.
- If `prev_dir` given, finds `basename(prev_dir)` in items and sets `selected_item`; otherwise `selected_item = 1`.
- Resets `scroll_offset = 0`.

### 02_04. handle_navigation_key(key)  {#SP_LFM_02_04}

Input: a KeyEvent (see [SP_SYS_01_01](./lfm_sys.sp.md#SP_SYS_01_01)).

Output: boolean — `true` if the key was consumed by panel logic.

Consumed keys:
| Key | Effect |
|-----|--------|
| `up` / `down` | move selection ±1 (clamped) |
| `pageup` / `pagedown` | ±`view_height` |
| `home` / `end` | first / last item |
| `tab` | flip `active_panel` |
| `enter` | if selected is readable directory, `open_dir` |
| `view` (F3) | `lfm_view.view_file` on readable non-directory |
| `edit` (F4) | `vi` on writable non-directory |
| `refresh` (Ctrl+R) | reload both panels, restore cursor by name |

### 02_05. main()  {#SP_LFM_02_05}

Program entry. Initializes panels, enters raw mode, runs the render/input loop until `key == "quit"` (F10). Restores tty on exit.

## 03. Validation Rules  {#SP_LFM_03}

### 03_01. Input Validation  {#SP_LFM_03_01}

- Target path passed to `open_dir` is **not** validated — caller must ensure it's a readable directory.
- Permission gates live in panel-dispatch (`enter`, `view`, `edit`), not in `open_dir`.

## 04. State Transitions  {#SP_LFM_04}

### 04_01. Active panel  {#SP_LFM_04_01}

    [panel1 active] --Tab--> [panel2 active]
    [panel2 active] --Tab--> [panel1 active]

### 04_02. Frame cycle  {#SP_LFM_04_02}

    [idle wait for key] --get_key--> [dispatch] --update state--> [redraw] --back to idle]

## 05. Verification Criteria  {#SP_LFM_05}

### 05_01. Functional Expectations  {#SP_LFM_05_01}

| Contract | Scenario | Steps | Expected |
|----------|----------|-------|----------|
| sort_items | Mixed entries | apply to random input | `".."` first, dirs grouped, case-insensitive |
| open_dir | Parent navigation | select `".."`, press enter | Panel shows parent; `selected_item` highlights previously-open subdir |
| open_dir | Child directory | enter on a subdir | Panel shows subdir; `selected_item = 1` |
| handle_navigation_key | Tab | press Tab | `active_panel` flips |
| handle_navigation_key | F3 on binary | press F3 on unreadable | No-op |
| main | F10 | press F10 | Loop exits, tty restored |

### 05_02. Invariant Checks  {#SP_LFM_05_02}

| Invariant | Verification method |
|-----------|-------------------|
| Tty restored on exit | `stty -a` after program exit shows cooked mode |
| Both panels always have items | After init, `#panel1.items ≥ 1` and same for panel 2 |
| Widths cover screen | `panel1.view_width + panel2.view_width + 3 == screen_width` |

### 05_03. Integration Scenarios  {#SP_LFM_05_03}

| Scenario | Preconditions | Steps | Expected |
|----------|---------------|-------|----------|
| Typed command wins over panel nav | command = `"ls"` typed in terminal | Press `up` | Cursor moves inside command input, panel unchanged |
| Terminal idle → panel nav wins | command empty, output empty | Press `up` | Panel selection moves up |
| Resize | run the app, resize terminal | — | Next frame adapts widths/heights |

### 05_04. Edge Cases  {#SP_LFM_05_04}

| Case | Input | Expected |
|------|-------|----------|
| Selection beyond refresh | `Ctrl+R` when selected item was deleted externally | **Known bug:** nil-deref at `panel.items[selected_item].name` — see issues.md |
| Empty directory | enter a readable empty dir | Panel shows only synthetic `..` |
| Unreadable selected dir | enter on it | No-op (silent permission skip) |

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initialized from existing codebase via onboard procedure |
