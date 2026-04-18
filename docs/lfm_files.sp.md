# File System Operations — Specification  {#SP_FIL}

> **Code:** SP_FIL
> **Status:** active
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Concept:** [C_FIL](./lfm_files.concept.md)
> **Depends on specs:** [SP_SYS](./lfm_sys.sp.md)
> **Used by specs:** [SP_VIW](./lfm_view.sp.md), [SP_LFM](./lfm.sp.md)
> **Plan:** [lfm_files.plan.md](./lfm_files.plan.md)

## 01. Data Structures  {#SP_FIL_01}

### 01_01. Item  {#SP_FIL_01_01}

A single filesystem entry surfaced to the UI.

Fields:
| Field | Type | Required | Default | Constraints | Description |
|-------|------|----------|---------|-------------|-------------|
| name | string | yes | — | basename only, no `/` | Display name |
| path | string | yes | — | absolute or root-prefixed | Full path for navigation |
| is_dir | boolean | yes | false | symlinks resolved before setting | True if directory |
| is_link | boolean | yes | false | — | True if symbolic link |
| link_target | string \| nil | no | nil | absolute path | Target of symlink, if `is_link` |
| permissions | string | yes | — | 10-char `-rwxrwxrwx` form | From stat `%A` |
| size | number | yes | 0 | ≥ 0; 0 for directories | Size in bytes |
| modified | string | yes | — | epoch seconds as string | From stat `%Y` |

Invariants:
- `is_dir` reflects the **target** type for symlinks.
- `name` does not contain `/`.
- `".."` synthetic entry is always `is_dir = true`, `is_link = false`, `size = 0`.

## 02. Contracts  {#SP_FIL_02}

### 02_01. get_absolute_path  {#SP_FIL_02_01}

Input:
| Parameter | Type | Required | Constraints |
|-----------|------|----------|-------------|
| path | string | yes | non-empty |

Output: canonical absolute path string. On `realpath` failure → returns input path (cached as identity).

Behavior:
- Cached: `abs_path_cache[path]` checked first.
- Calls `lfm_sys.exec_command_output('realpath "<path>" 2>/dev/null')`.
- Stores result (or input) in cache.

### 02_02. clear_path_cache  {#SP_FIL_02_02}

Side-effect only. Clears `abs_path_cache`. Called on every directory change in the UI.

### 02_03. get_directory_items  {#SP_FIL_02_03}

Input:
| Parameter | Type | Required | Constraints |
|-----------|------|----------|-------------|
| path | string | yes | valid directory path |

Output: `Item[]` (see [SP_FIL_01_01](#SP_FIL_01_01)).

Errors:
- Missing/unreadable directory → items contains only the synthetic `..` (if not `/`) or is empty.

### 02_04. check_permissions  {#SP_FIL_02_04}

Input:
| Parameter | Type | Required | Constraints |
|-----------|------|----------|-------------|
| permissions | string | yes | mode string from `stat %A`; ≥ 4 chars |
| action | string | yes | one of `"read"`, `"write"`, `"execute"` |

Output: `true` or `false`.

Rules:
- Consults the **owner** triplet only — positions 2-4 of the mode string.
- `read` → position 2 must be `r`.
- `write` → position 3 must be `w`.
- `execute` → position 4 must be `x`.
- Input shorter than 4 chars or unknown `action` → `false`.
- `nil` permissions → `false`.

### 02_05. get_basename  {#SP_FIL_02_05}

Input: path string. Output: last path component with trailing slashes stripped.

## 03. Validation Rules  {#SP_FIL_03}

### 03_01. Input Validation  {#SP_FIL_03_01}

- All paths passed to shell commands go through [SP_SYS_02_00 shell_quote](./lfm_sys.sp.md#SP_SYS_02_00) — safe for any byte except NUL (POSIX filenames cannot contain NUL).
- `stat --printf` uses NUL as field separator, so filenames containing `|`, spaces, or newlines are preserved intact.

## 05. Verification Criteria  {#SP_FIL_05}

### 05_01. Functional Expectations  {#SP_FIL_05_01}

| Contract | Scenario | Input | Expected |
|----------|----------|-------|----------|
| get_absolute_path | Relative | `"."` | current working dir absolute |
| get_absolute_path | Cache hit | same path twice | second call returns cached value without spawning |
| get_absolute_path | Path with apostrophe | `"/tmp/can't"` | canonicalized, no shell injection |
| get_directory_items | Non-root | `"/tmp"` | list includes `..`, `is_dir` for subdirs |
| get_directory_items | Root | `"/"` | list does NOT include `..` |
| get_directory_items | Filename with `\|`, `'`, `$`, space | ambient dir | each file is listed with its exact name |
| check_permissions | owner-readable | `"-rwxr-xr-x"`, `"read"` | `true` |
| check_permissions | owner-writable | `"-rwxr-xr-x"`, `"write"` | `true` |
| check_permissions | owner-executable | `"-rwxr-xr-x"`, `"execute"` | `true` |
| check_permissions | group-writable only | `"-r--rw-r--"`, `"write"` | `false` — owner bit required |
| check_permissions | other-executable only | `"-r--r--r-x"`, `"execute"` | `false` — owner bit required |
| check_permissions | nil | `nil, "read"` | `false` |
| check_permissions | unknown action | `"-rwxrwxrwx"`, `"bogus"` | `false` |
| get_basename | trailing slash | `"/a/b/"` | `"b"` |

### 05_02. Invariant Checks  {#SP_FIL_05_02}

| Invariant | Verification method |
|-----------|-------------------|
| Cache consistency | After `clear_path_cache`, next `get_absolute_path` re-spawns realpath |
| Owner-triplet only | `check_permissions` with group-only perms returns false |

### 05_03. Integration Scenarios  {#SP_FIL_05_03}

| Scenario | Preconditions | Steps | Expected result |
|----------|--------------|-------|-----------------|
| Symlink navigation | Dir contains `link -> /etc` | Select link, press Enter | Panel navigates into `/etc`, `items[0].name == ".."` |

### 05_04. Edge Cases and Boundaries  {#SP_FIL_05_04}

| Case | Input | Expected |
|------|-------|----------|
| Broken symlink | link → non-existent | `is_link = true`, `is_dir = false` |
| Path with trailing `/` | `"/tmp/"` | Normalized during stat glob |

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initialized from existing codebase via onboard procedure |
| 2026-04-18 | Switched stat parsing to NUL-separated fields (`|` in filenames no longer breaks listing). All shell-invoked paths now go through `shell_quote`. Clarified `check_permissions` — owner triplet means positions 2-4 of the mode string; read/write/execute now correctly examine positions 2/3/4 respectively. |
