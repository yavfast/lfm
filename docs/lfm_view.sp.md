# File Viewer — Specification  {#SP_VIW}

> **Code:** SP_VIW
> **Status:** active
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Concept:** [C_VIW](./lfm_view.concept.md)
> **Depends on specs:** [SP_FIL](./lfm_files.sp.md), [SP_SCR](./lfm_scr.sp.md), [SP_SYS](./lfm_sys.sp.md)
> **Used by specs:** [SP_LFM](./lfm.sp.md)
> **Plan:** [lfm_view.plan.md](./lfm_view.plan.md)

## 01. Data Structures  {#SP_VIW_01}

### 01_01. ViewerViewport (local)  {#SP_VIW_01_01}

Not exposed externally. Lives on the call stack of `view_file`.

Fields:
| Field | Type | Default | Constraints | Description |
|-------|------|---------|-------------|-------------|
| current_line | integer | 1 | `1 ≤ current_line ≤ max(1, #lines - max_lines + 1)` | First visible line (1-indexed) |
| current_col | integer | 0 | ≥ 0 | Horizontal offset (chars) |
| header_height | integer | 2 | const | Header rows consumed |
| footer_height | integer | 2 | const | Footer rows consumed |
| max_lines | integer | `view_height - 4` | ≥ 0 | Rendered lines per frame |

## 02. Contracts  {#SP_VIW_02}

### 02_01. view_file(path, view_width, view_height)  {#SP_VIW_02_01}

Purpose: Enter pager mode, display `path`, return when user presses `q` or `escape`.

Input:
| Parameter | Type | Required | Constraints |
|-----------|------|----------|-------------|
| path | string | yes | readable file path |
| view_width | integer | yes | ≥ 4 (to fit `"..."` truncation) |
| view_height | integer | yes | ≥ 5 (header 2 + footer 2 + ≥ 1 content row) |

Output: —. Blocks until user quits.

Errors:
| Code | Condition | Guidance |
|------|-----------|----------|
| — | `io.open` fails | Silent return; caller never enters pager mode |

Processing logic (pseudocode):

    FUNCTION view_file(path, view_width, view_height):
        handle = io.open(path, "r")
        IF not handle: return
        content = handle:read("*a"); handle:close()
        lines = split(content, "\r?\n")
        init_terminal(); enter_fullscreen(); clear_screen()
        draw_header(absolute_path(path))
        viewport = {current_line=1, current_col=0, max_lines=view_height-4}
        LOOP:
            redraw_content()
            draw_footer()
            key = get_key()
            IF key in {"q", "escape"}: break
            update viewport per key
        exit_fullscreen(); restore_terminal()

Key bindings:
| Key | Effect |
|-----|--------|
| `up` / `down` | move 1 line |
| `pageup` / `pagedown` | move `max_lines` |
| `home` / `end` | first / last page |
| `left` / `right` | horizontal ±10 chars |
| `q` / `escape` | exit |

## 03. Validation Rules  {#SP_VIW_03}

### 03_01. Input Validation  {#SP_VIW_03_01}

- `view_height < 5` results in `max_lines ≤ 0` — rendering produces a blank screen but does not crash.

## 05. Verification Criteria  {#SP_VIW_05}

### 05_01. Functional Expectations  {#SP_VIW_05_01}

| Contract | Scenario | Steps | Expected |
|----------|----------|-------|----------|
| view_file | Text file | F3 on readable text file → press `down` | Next line visible, position indicator updates |
| view_file | Missing file | pass non-existent path | Immediate return, no screen takeover |
| view_file | Long line | line wider than `view_width` | Truncated with `...`; `right` scrolls to reveal |
| view_file | Quit | press `q` | Returns to main file-manager screen; cursor visible |

### 05_02. Invariant Checks  {#SP_VIW_05_02}

| Invariant | Verification method |
|-----------|-------------------|
| Terminal restored | After exit, raw mode off and main buffer restored |
| No rendering past EOF | `current_line` never exceeds `#lines - max_lines + 1` |

### 05_03. Integration Scenarios  {#SP_VIW_05_03}

| Scenario | Preconditions | Steps | Expected |
|----------|---------------|-------|----------|
| F3 cycle | main loop in raw mode | F3 → viewer → q → back to main | Both screens preserved; tty mode restored |

### 05_04. Edge Cases  {#SP_VIW_05_04}

| Case | Input | Expected |
|------|-------|----------|
| Empty file | 0 bytes | Single blank content area; position `[1-1/0]` |
| Binary file | gzip / png | Garbled render; exit via `q` still clean |
| `view_width = 3` | — | Any non-empty line becomes `...` |

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initialized from existing codebase via onboard procedure |
