# File Viewer  {#C_VIW}

> **Code:** C_VIW
> **Status:** active
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
> **Author:** onboard
>
> **Depends on:** [C_FIL](./lfm_files.concept.md), [C_SCR](./lfm_scr.concept.md), [C_SYS](./lfm_sys.concept.md)
> **Used by:** [C_LFM](./lfm.concept.md)
> **Specification:** [SP_VIW](./lfm_view.sp.md)
> **Plan:** [lfm_view.plan.md](./lfm_view.plan.md)
>
> Read-only pager invoked on F3. Renders a text file in the alternate screen buffer with vertical and horizontal scrolling.

## 1. Philosophy  {#C_VIW_01}

### 1.1. Core Principle  {#C_VIW_01_01}

Users need to preview text files without leaving the file manager. A self-contained viewer is simpler than delegating to `less` — no external state, predictable keybindings.

### 1.2. Design Constraints  {#C_VIW_01_02}

- Reads entire file into memory — OK for typical source files, not for gigabyte logs.
- Renders in alternate screen buffer so main file-manager UI is preserved on exit.
- Read-only — no editing, no search (yet).

## 2. Domain Model  {#C_VIW_02}

### 2.1. Key Entities  {#C_VIW_02_01}

- **Lines** — array of strings split on `\r?\n`.
- **Viewport** — `(current_line, current_col, max_lines)`.

### 2.2. Data Flows  {#C_VIW_02_02}

File path → `io.open` → full read → split to lines → render loop (keystroke → update viewport → redraw).

## 3. Mechanisms  {#C_VIW_03}

### 3.1. Core Algorithm  {#C_VIW_03_01}

Render loop per keystroke:
1. Clear lines from `header_height + 1` to `header_height + max_lines`.
2. For `i = 1..max_lines`: slice line `current_line + i - 1` from column `current_col`, truncate to `view_width`, draw.
3. Draw footer with position info.
4. Wait for next key; update viewport or break.

### 3.2. Edge Cases  {#C_VIW_03_02}

- File open failure → silent return.
- Binary / non-text content → may corrupt the terminal (no content-type check).
- Horizontal scroll past line end → blank rows.

## 4. Integration Points  {#C_VIW_04}

### 4.1. Dependencies  {#C_VIW_04_01}

- [C_FIL](./lfm_files.concept.md) — absolute-path resolution for header.
- [C_SCR](./lfm_scr.concept.md) — rendering primitives.
- [C_SYS](./lfm_sys.concept.md) — tty mode and `get_key`.

### 4.2. API Surface  {#C_VIW_04_02}

- `view_file(path, view_width, view_height)` — single blocking entry point.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initialized from existing codebase via onboard procedure |
