# System Primitives  {#C_SYS}

> **Code:** C_SYS
> **Status:** active
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
> **Author:** onboard
>
> **Depends on:** none
> **Used by:** [C_FIL](./lfm_files.concept.md), [C_VIW](./lfm_view.concept.md), [C_LFM](./lfm.concept.md)
> **Specification:** [SP_SYS](./lfm_sys.sp.md)
> **Plan:** [lfm_sys.plan.md](./lfm_sys.plan.md)
>
> Thin wrapper over Unix system calls — shell command execution, terminal geometry, tty mode management, and symbolic decoding of keyboard input.

## 1. Philosophy  {#C_SYS_01}

### 1.1. Core Principle  {#C_SYS_01_01}

The rest of the program should never touch `io.popen`, `os.execute`, or raw escape sequences by hand. `lfm_sys` is the single funnel through which every system interaction passes, so future port work (Windows, BSD, testing harness) has exactly one module to patch.

### 1.2. Design Constraints  {#C_SYS_01_02}

- Zero external libraries — only Lua stdlib + shell-out.
- All shell commands run with `LANG=C` for parseable output.
- Failure modes never throw: return `nil`, or sensible fallback values (24×80, "N/A").
- Key decoding is symbolic — callers branch on `"up"`, `"quit"`, not byte sequences.

## 2. Domain Model  {#C_SYS_02}

### 2.1. Key Entities  {#C_SYS_02_01}

- **Command invocation** — pair of (shell string → stdout string) via `io.popen`.
- **Terminal geometry** — `(rows, cols)` from `stty size`.
- **Tty mode** — boolean global state: raw/cooked. Transitions via `stty`.
- **Key event** — symbolic string returned by `get_key`, produced from one or more raw bytes.

### 2.2. Data Flows  {#C_SYS_02_02}

```
User keystroke ──► tty ──► io.read(1) ──► escape decoder ──► symbolic key
Shell command  ──► io.popen(LANG=C cmd) ──► handle:read("*a") ──► string
```

## 3. Mechanisms  {#C_SYS_03}

### 3.1. Core Algorithm  {#C_SYS_03_01}

- `exec_command_output(cmd)`: prepend `LANG=C `, open via `io.popen`, read everything, close, return.
- `get_key()`: read one byte. If ESC, use timed non-blocking read to disambiguate lone ESC from `ESC [ …` sequences; walk a decision tree to recognize arrows, function keys, modifiers.
- Raw/cooked toggle: `stty raw -echo` / `stty -raw echo`.

### 3.2. Edge Cases  {#C_SYS_03_02}

- `io.popen` can fail — handle is nil, return nil-typed default.
- Unknown escape sequences return `nil` (dropped), not an error.
- `read_with_timeout` changes `icanon/min/time` temporarily; must always restore to blocking.

## 4. Integration Points  {#C_SYS_04}

### 4.1. Dependencies  {#C_SYS_04_01}

None. `lfm_sys` is a foundation module.

### 4.2. API Surface  {#C_SYS_04_02}

- **Command exec:** `exec_command_output`.
- **Geometry/info:** `get_terminal_size`, `get_ram_info`, `format_size`.
- **Tty:** `init_terminal`, `restore_terminal`.
- **Input:** `get_key`.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initialized from existing codebase via onboard procedure |
