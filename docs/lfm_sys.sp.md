# System Primitives — Specification  {#SP_SYS}

> **Code:** SP_SYS
> **Status:** active
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Concept:** [C_SYS](./lfm_sys.concept.md)
> **Depends on specs:** none
> **Used by specs:** [SP_FIL](./lfm_files.sp.md), [SP_VIW](./lfm_view.sp.md), [SP_LFM](./lfm.sp.md)
> **Plan:** [lfm_sys.plan.md](./lfm_sys.plan.md)
>
> Exact contracts for shell execution, terminal geometry, tty-mode management, and key decoding.

## 01. Data Structures  {#SP_SYS_01}

> Implements: [C_SYS_02](./lfm_sys.concept.md#C_SYS_02)

### 01_01. KeyEvent (string)  {#SP_SYS_01_01}

Symbolic key names returned by `get_key`. Not a Lua type — just a fixed string vocabulary callers match against.

| Value | Origin |
|-------|--------|
| `up`, `down`, `left`, `right` | ANSI arrow escapes |
| `pageup`, `pagedown`, `home`, `end` | ANSI paging escapes |
| `ctrl_up`, `ctrl_down`, `ctrl_shift_up`, `ctrl_shift_down` | `ESC [ 1 ; 5/6 A/B` |
| `view` | F3 (`ESC O R`) |
| `edit` | F4 (`ESC O S`) |
| `quit` | F10 (`ESC [ 2 1 ~`) |
| `escape` | ESC alone |
| `enter` | `\r` |
| `tab` | `\t` |
| `refresh` | Ctrl+R (`\18`) |
| any single byte | printable or unhandled byte, returned verbatim |

Invariants:
- Exactly one of: a symbolic string, a single printable byte, or `nil` (unknown escape sequence).

## 02. Contracts  {#SP_SYS_02}

### 02_00. shell_quote  {#SP_SYS_02_00}

Purpose: Wrap a value for safe use inside a POSIX shell command.

Input:
| Parameter | Type | Required | Constraints |
|-----------|------|----------|-------------|
| s | string \| nil | no | any byte sequence; nil → `''` |

Output: single-quoted string; single quotes inside `s` are encoded as `'\''`.

Invariants:
- Output is always surrounded by single quotes.
- `shell_quote(x)` followed by concatenation into a shell command is safe for any `x` that does not contain a NUL byte (POSIX filenames cannot contain NUL).

### 02_01. exec_command_output  {#SP_SYS_02_01}

Purpose: Run a shell command with `LANG=C` and return its stdout.

Input:
| Parameter | Type | Required | Constraints |
|-----------|------|----------|-------------|
| command | string | yes | Non-empty shell command; caller is responsible for escaping |

Output:
| Field | Type | Description |
|-------|------|-------------|
| — | string \| nil | stdout as a single string, or `nil` if `io.popen` failed |

Errors: returns `nil` on spawn failure; does not raise.

### 02_02. get_terminal_size  {#SP_SYS_02_02}

Output: `rows, cols` (two numbers). Fallback `24, 80`.

### 02_03. format_size  {#SP_SYS_02_03}

Input: `bytes : number`. Output: string like `"512"`, `"1.3K"`, `"5.2M"`. Unit ladder `'', K, M, G, T`, promotes when `size > 1024`.

### 02_04. get_ram_info  {#SP_SYS_02_04}

Output: `"RAM: <used> / <total>"` or `"RAM: N/A"`. Values formatted via `format_size`. Total and used are read from `free` output `Mem:` line (kB), converted to bytes.

### 02_05. init_terminal / restore_terminal  {#SP_SYS_02_05}

Side-effect only. `init_terminal` executes `stty raw -echo`; `restore_terminal` executes `stty -raw echo`. No inputs, no outputs.

### 02_06. get_key  {#SP_SYS_02_06}

Output: a `KeyEvent`. Blocking; returns when at least one byte is read.

Errors:
| Code | Condition | Guidance |
|------|-----------|----------|
| `nil-return` | Unknown / incomplete escape sequence | Caller treats as no-op |

Processing logic (pseudocode):

    FUNCTION get_key():
        key = io.read(1)
        IF key == nil: return nil
        IF key == ESC:
            next1 = read_with_timeout()
            IF next1 == nil: return "escape"
            IF next1 == "[": decode CSI sequence
            IF next1 == "O": decode F3/F4
            return nil  -- unknown
        IF key == "\r": return "enter"
        IF key == "\18": return "refresh"
        IF key == "\t": return "tab"
        return key     -- any other single byte

## 03. Validation Rules  {#SP_SYS_03}

### 03_01. Input Validation  {#SP_SYS_03_01}

- Every `io.popen` handle must be nil-checked before use.
- Every call to `init_terminal` must be paired with a call to `restore_terminal` before program exit or external program launch.
- `format_size` is pure; no side effects.

## 04. State Transitions  {#SP_SYS_04}

### 04_01. Tty Mode Lifecycle  {#SP_SYS_04_01}

State diagram:

    [cooked] --init_terminal()--> [raw]
    [raw]    --restore_terminal()--> [cooked]

Transition rules:
| From | To | Condition | Side effects |
|------|----|-----------|-------------|
| cooked | raw | `init_terminal()` | `stty raw -echo` |
| raw | cooked | `restore_terminal()` | `stty -raw echo` |

## 05. Verification Criteria  {#SP_SYS_05}

### 05_01. Functional Expectations  {#SP_SYS_05_01}

| Contract | Scenario | Input | Expected outcome |
|----------|----------|-------|------------------|
| shell_quote | plain | `"abc"` | `"'abc'"` |
| shell_quote | spaces | `"a b c"` | `"'a b c'"` |
| shell_quote | apostrophe | `"a'b"` | `"'a'\\''b'"` |
| shell_quote | `$` and backticks | `[[` "$x `y` `]]` | input wrapped unchanged in single quotes |
| shell_quote | nil | `nil` | `"''"` |
| exec_command_output | Happy path | `"echo hi"` | `"hi\n"` |
| exec_command_output | Failed spawn | invalid command | `nil` (no raise) |
| get_terminal_size | `stty size` available | — | two numbers > 0 |
| get_terminal_size | `stty` missing | — | `24, 80` |
| format_size | 0 | `0` | `"0"` |
| format_size | 1023 | `1023` | `"1023"` |
| format_size | 1024 (boundary) | `1024` | `"1024"` — strict `>` check, 1024 stays as-is |
| format_size | 1025 | `1025` | `"1.0K"` |
| format_size | 2 GiB | `2 * 1024^3 + 1` | `"2.0G"` |
| get_ram_info | `free` parseable | — | `"RAM: <used>/<total>"` |
| get_ram_info | `free` missing | — | `"RAM: N/A"` |
| get_key | arrow up | `ESC [ A` bytes | `"up"` |
| get_key | ESC alone | `ESC` (no follow-up) | `"escape"` |
| get_key | printable | `"a"` | `"a"` |
| get_key | unknown escape | `ESC [ Z` | `nil` |

### 05_02. Invariant Checks  {#SP_SYS_05_02}

| Invariant | Verification method |
|-----------|-------------------|
| Raw mode paired | Manual: any path from `init_terminal` eventually hits `restore_terminal` |
| LANG=C prefix | Grep `exec_command_output` — all call sites prepend `LANG=C` |

### 05_03. Integration Scenarios  {#SP_SYS_05_03}

| Scenario | Preconditions | Steps | Expected result |
|----------|--------------|-------|-----------------|
| Enter/exit viewer | In main loop, raw mode | Press F3 → viewer runs → press q | Raw mode restored after viewer exit, main loop continues |

### 05_04. Edge Cases and Boundaries  {#SP_SYS_05_04}

| Case | Input | Expected behavior |
|------|-------|-------------------|
| Empty stdout | `"true"` | `""` (empty string, not nil) |
| Tty size with junk in output | `stty size` → garbage | fallback `24, 80` |
| Malformed `free` output | no `Mem:` line | `"RAM: N/A"` |

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initialized from existing codebase via onboard procedure |
| 2026-04-18 | Added [SP_SYS_02_00 shell_quote](#SP_SYS_02_00). Corrected format_size boundary examples — strict `>` means 1024 stays `"1024"`. |
