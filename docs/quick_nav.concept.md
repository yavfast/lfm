# Quick Navigation — Alt+letter first-char jump  {#C_NAV}

> **Code:** C_NAV
> **Status:** active
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Depends on:** [C_LFM](./lfm.concept.md), [C_SYS](./lfm_sys.concept.md)
> **Used by:** —
> **Specification:** [SP_NAV](./quick_nav.sp.md)
> **Plan:** [PL_NAV](./quick_nav.plan.md)
>
> FAR-style cursor jump: `Alt+<letter>` moves the active panel's cursor to the next item whose name starts with that letter.

## 1. Philosophy  {#C_NAV_01}

### 1.1. Core Principle  {#C_NAV_01_01}

Quick in-list navigation without committing a printable character as a panel-only hotkey. `Alt+<letter>` sends `\27<letter>` (ESC prefix), which is unambiguously distinguishable from terminal command-line input — so the same letter can still be typed freely into the embedded shell.

### 1.2. Design Constraints  {#C_NAV_01_02}

- **Single-letter, non-incremental.** Press `Alt+n` → cursor jumps to next `n*` item. No search prefix buffer, no timeout state. Repeat the same key to advance through matches.
- **Wraps around the list** on subsequent presses.
- **Case-insensitive matching** — `Alt+n` matches both `notes.txt` and `Notes.txt`.
- **Dotfiles and `..` are skipped** — matching checks the first *non-dot* character. This lets `Alt+h` match `.hidden` only when hidden files are shown and the user meaningfully wants to jump to them; matching on the leading dot would be more confusing than useful.
- **Always panel-scoped**, regardless of terminal widget state. Even when the terminal has pending command text, `Alt+<letter>` dispatches to the panel (not inserted as text).

### 1.3. Scope boundary  {#C_NAV_01_03}

**IN SCOPE:**

- `Alt+<letter>` for letters `a`..`z` and `A`..`Z`.
- Wrap-around search that skips `..` and dotfiles.

**OUT OF SCOPE:**

- Incremental search with a multi-char prefix buffer (roadmap [R-NAV-01](./roadmap.plan.md#task-r-nav-01) — proposed separately).
- `Alt+<digit>` or `Alt+<punctuation>` — not mapped.
- `Alt+Shift+<letter>` as a reverse-direction jump — YAGNI; repeat + wrap covers the use case.

## 2. Domain Model  {#C_NAV_02}

### 2.1. Key Entities  {#C_NAV_02_01}

- **AltLetterToken** — `"alt_<letter>"` where `<letter>` is lowercased (`alt_a`..`alt_z`). Emitted by `lfm_sys.get_key` when it sees `\27<letter>` with `<letter>` in `[A-Za-z]`.

### 2.2. Data Flows  {#C_NAV_02_02}

```
Alt+n
  ├── get_key → "alt_n"
  ├── main-loop force-panel gate (always routes alt_* to panel)
  ├── handle_navigation_key:
  │     extract letter → scan active panel's items starting at (cursor + 1)
  │     match = first item with name:sub(1,1):lower() == letter (skipping .. and dotfiles)
  │     if found → update panel.selected_item
  └── redraw
```

## 3. Mechanisms  {#C_NAV_03}

### 3.1. Key decoding  {#C_NAV_03_01}

In `lfm_sys.get_key`, after the existing `\27[...` and `\27O...` branches, add a final branch: if `next1` is an ASCII letter, return `"alt_" .. next1:lower()`.

Edge-case precedence:

- Pure ESC remains "escape" (timeout on `read_with_timeout`).
- `\27[...` CSI sequences and `\27O...` SS3 sequences remain unchanged.
- `\27<punct>` (e.g., `\27.`, `\27/`) — not currently mapped, returns nil.

### 3.2. Main-loop dispatch override  {#C_NAV_03_02}

The main loop's existing rule — "if terminal has a pending command, send keys to terminal first" — MUST be relaxed for `alt_*` tokens. `Alt+<letter>` is always a panel action. This is implemented as a small pre-check that forces `handle_navigation_key` to be tried first when the key string starts with `"alt_"`.

### 3.3. Search algorithm  {#C_NAV_03_03}

Given `panel`, `letter`:

    local start = panel.selected_item + 1
    local n = #panel.items
    for offset = 0, n - 1 do
        local i = ((start - 1 + offset) % n) + 1
        local it = panel.items[i]
        if it and it.name ~= ".." and it.name:sub(1, 1) ~= "." then
            if it.name:sub(1, 1):lower() == letter then
                panel.selected_item = i
                return
            end
        end
    end

Start from `selected_item + 1` so that repeat presses advance forward. Wrap via modulo. Skip `..` and dotfiles.

### 3.4. Edge Cases  {#C_NAV_03_04}

- **No match** — cursor unchanged. No user-visible notification; the user re-tries or moves on.
- **Exactly one match** — cursor lands on it. Subsequent same-letter presses cycle (trivially stay on the same item since wrap finds it again).
- **Cursor already on a matching item** — next press moves to the next match (because we start at `selected_item + 1`).
- **All items filtered out by hidden** — empty panel (except `..`); Alt+letter is a no-op.

## 4. Integration Points  {#C_NAV_04}

### 4.1. Dependencies  {#C_NAV_04_01}

- **`lfm_sys`** — decoder extension.
- **`lfm.lua`** — dispatch arm, main-loop gate adjustment.

### 4.2. Public API changes  {#C_NAV_04_02}

None beyond the new `"alt_<letter>"` key token.

## 5. Non-Goals  {#C_NAV_05}

- Not a replacement for incremental search (future R-NAV-01).
- Not a match-highlighting system — only cursor movement.
- Not a directory-traversal shortcut — pure within-panel jump.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initial version — delivered together with the hotkey cleanup that removed `*` / `=` panel bindings. |
