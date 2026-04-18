# Specification: Quick Navigation (Alt+letter)  {#SP_NAV}

> **Code:** SP_NAV
> **Status:** active
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Concept:** [C_NAV](./quick_nav.concept.md)
> **Plan:** [PL_NAV](./quick_nav.plan.md)

## 1. Key Dispatch  {#SP_NAV_01}

### 1.1. Decoder token  {#SP_NAV_01_01}

| Input | Token |
|-------|-------|
| `\27` followed by `[A-Za-z]` (within `read_with_timeout`) | `"alt_" .. letter:lower()` |

`\27` followed by `[`, `O`, digits, or anything else retains its existing meaning (CSI / SS3 / nil).

### 1.2. Main-loop override  {#SP_NAV_01_02}

Alt+letter tokens MUST reach `handle_navigation_key` even when `lfm_terminal.has_command()` is true. Implemented by forcing the panel-try gate when `key:sub(1, 4) == "alt_"`.

## 2. Search Contract  {#SP_NAV_02}

### 2.1. `handle_alt_letter(panel, letter) -> nil`  {#SP_NAV_02_01}

- **Input:** active `panel`, a single lowercase ASCII letter.
- **Output:** mutates `panel.selected_item` to the first matching item found by the algorithm below; otherwise leaves it unchanged.
- **Algorithm:** starting at `panel.selected_item + 1` (wrapping), scan items and pick the first one where:
  - `name ~= ".."`
  - `name:sub(1, 1) ~= "."` (dotfiles excluded)
  - `name:sub(1, 1):lower() == letter`
- **Invariant:** does not modify `panel.selected`, `panel.scroll_offset`, or any other panel field beyond `selected_item`. Scroll position is corrected by the existing `update_scroll(panel)` on the next render frame.

## 3. Error Cases  {#SP_NAV_03}

| Scenario | Behavior |
|----------|----------|
| No match for letter | `panel.selected_item` unchanged; redraw is still issued. |
| Panel has only `..` | No match; no-op. |
| Letter is a non-letter key (shouldn't happen — decoder only emits letters) | Silently ignored. |
| Terminal widget has pending input | Main-loop override routes `alt_*` to panel regardless. |

## 4. Integration Scenarios  {#SP_NAV_04}

### 4.1. Jump across a directory listing  {#SP_NAV_04_01}

1. Panel contains: `.. / nested / alpha.txt / banana.txt / zulu.log`, cursor on `..`.
2. User presses `Alt+b` → cursor jumps to `banana.txt` (first `b` match after `..`).
3. User presses `Alt+b` again → cursor wraps, no other `b` items → stays on `banana.txt`.
4. User presses `Alt+z` → cursor jumps to `zulu.log`.
5. User presses `Alt+n` → skips dirs? No — dirs are regular matches. `nested` starts with `n` → cursor jumps to `nested`.

### 4.2. Repeat cycles through matches  {#SP_NAV_04_02}

1. Panel contains three `a*` files: `alpha.txt`, `apple.md`, `ant.sh`.
2. Cursor on `..`.
3. `Alt+a` → `alpha.txt` (first in the sorted list).
4. `Alt+a` → `ant.sh` (next after current).
5. `Alt+a` → `apple.md`.
6. `Alt+a` → wraps to `alpha.txt`.

### 4.3. Interaction with terminal input  {#SP_NAV_04_03}

1. User types `ls -l` in the terminal (command buffer has 5 chars).
2. Presses `Alt+b` on panel.
3. Panel cursor jumps to first `b*` item.
4. Terminal command line is unaffected (still shows `ls -l`).

## 5. Verification Criteria  {#SP_NAV_05}

### 5.1. Live-verifiable via agent-tui  {#SP_NAV_05_01}

Fixture with files `alpha.txt`, `beta.txt`, `banana.md`, subdir `notes/`, dotfile `.hidden`. Tests:

- `Alt+b` → cursor on `beta.txt` (first `b` after `..`).
- `Alt+b` again → `banana.md` (second match).
- `Alt+b` again → wrap to `beta.txt`.
- `Alt+n` → `notes/` (directory also matches).
- `Alt+h` when hidden-off → no match (`.hidden` filtered out anyway).
- With terminal command text pending: `Alt+a` still jumps panel cursor; terminal text intact.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initial. |
