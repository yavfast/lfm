# File Manager Entry Point  {#C_LFM}

> **Code:** C_LFM
> **Status:** active
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
> **Author:** onboard
>
> **Depends on:** [C_SYS](./lfm_sys.concept.md), [C_FIL](./lfm_files.concept.md), [C_SCR](./lfm_scr.concept.md), [C_VIW](./lfm_view.concept.md), [C_STR](./lfm_str.concept.md), [C_TRM](./lfm_terminal.concept.md)
> **Used by:** —
> **Specification:** [SP_LFM](./lfm.sp.md)
> **Plan:** [lfm.plan.md](./lfm.plan.md)
>
> Program entry point — renders a two-panel file manager with an embedded shell terminal, translates keystrokes into panel / viewer / editor / terminal actions.

## 1. Philosophy  {#C_LFM_01}

### 1.1. Core Principle  {#C_LFM_01_01}

A minimalist Midnight-Commander-style interface: two side-by-side file panels, an embedded terminal at the bottom, hotkeys across the top of the screen. All rendering is recomputed every frame so that `stty size` changes (terminal resize) take effect immediately.

### 1.2. Design Constraints  {#C_LFM_01_02}

- Single process, single thread, blocking read loop.
- No configuration — all layout parameters are constants in [lfm.lua](../lfm.lua).
- No pcall around main loop — any crash leaves raw mode active.

## 2. Domain Model  {#C_LFM_02}

### 2.1. Key Entities  {#C_LFM_02_01}

- **Panel** — `{ current_dir, absolute_path, selected_item, scroll_offset, items, view_width, view_height }`.
- **ScreenLayout** — computed per frame: terminal-height (30% of screen, min 5), main-height, widths.
- **Active-panel index** — `1` or `2`, flipped by `Tab`.

### 2.2. Data Flows  {#C_LFM_02_02}

```
get_key()
  ├── quit      → break main loop
  ├── panel nav → update panel selection / scroll / directory
  ├── F3/F4     → restore tty → viewer/vi → re-init tty
  └── other     → terminal widget (input or scroll)

display_file_manager()
  ├── get_terminal_size           → update screen_info / screen_layout
  ├── draw_header                 → title + RAM + two path bars
  ├── draw_panels_content         → two file lists with separators
  ├── draw_footer                 → [idx/total]= padding
  ├── lfm_terminal.draw_terminal  → embedded shell widget
  └── draw_hints                  → F3/F4/Ctrl+R/Tab/F10 bar
```

## 3. Mechanisms  {#C_LFM_03}

### 3.1. Core Algorithm  {#C_LFM_03_01}

Main loop:

    os.execute("clear")
    load panel1 (".") → sort
    load panel2 (".") → sort
    init_terminal()
    while true:
        display_file_manager()
        key = lfm_sys.get_key()
        if key == "quit": break
        if terminal.has_command() or not panel_navigation(key):
            if not terminal.handle_navigation_key(key):
                terminal.handle_input(key)
    restore_terminal()

Key dispatch priority when the terminal has no text in the input:
1. Panel-level keys (`up`, `down`, `enter`, `tab`, …).
2. Terminal cursor/scroll keys (only if consumable).
3. Fallback: terminal input (insert as character).

When the terminal has text in the input, **all** keys go to the terminal first — preventing accidental panel navigation while typing.

### 3.2. Edge Cases  {#C_LFM_03_02}

- Directory with fewer items than view height — rows beyond `#items` render as blank.
- External programs (vi, viewer, user shell commands) require raw-mode round-trip.
- Terminal resize is picked up at the start of the next frame (`get_terminal_size`); no signal handling.
- `Ctrl+R` refresh calls `panel.items[selected].name` — throws if `selected` is out of bounds.

## 4. Integration Points  {#C_LFM_04}

### 4.1. Dependencies  {#C_LFM_04_01}

All other modules. This is the program top.

### 4.2. API Surface  {#C_LFM_04_02}

No public API. `lfm.lua` is executed with `lua lfm.lua` (or via the `#!lua` shebang) and runs to completion.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initialized from existing codebase via onboard procedure |
