# File System Operations  {#C_FIL}

> **Code:** C_FIL
> **Status:** active
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
> **Author:** onboard
>
> **Depends on:** [C_SYS](./lfm_sys.concept.md)
> **Used by:** [C_VIW](./lfm_view.concept.md), [C_LFM](./lfm.concept.md)
> **Specification:** [SP_FIL](./lfm_files.sp.md)
> **Plan:** [lfm_files.plan.md](./lfm_files.plan.md)
>
> Directory listing, absolute-path resolution (memoized), permission inspection, and basename extraction — all built on top of `stat` / `realpath`.

## 1. Philosophy  {#C_FIL_01}

### 1.1. Core Principle  {#C_FIL_01_01}

The UI needs a single function that takes a directory path and returns a sorted, rendered-ready list of items. Everything else (symlink resolution, permission bits, size formatting) must be figured out without the UI branching on OS-specific edge cases.

### 1.2. Design Constraints  {#C_FIL_01_02}

- No FFI — shell out to `stat` and `realpath`.
- No persistent cache on disk — only in-memory `abs_path_cache`, cleared on every directory change.
- Permissions model: owner triplet only. No uid/gid, no group/other checks.
- Directories glob both `path/*` and `path/.*` to include dotfiles.

## 2. Domain Model  {#C_FIL_02}

### 2.1. Key Entities  {#C_FIL_02_01}

- **Item** — the projected record for a single filesystem entry (name, path, is_dir, is_link, link_target, permissions, size, modified). See [SP_FIL_01_01](./lfm_files.sp.md#SP_FIL_01_01).
- **Synthetic `..`** — a fabricated entry prepended to non-root directories so the UI always has a way back up.
- **Absolute-path cache** — module-level map from user-provided path to its canonical absolute path.

### 2.2. Data Flows  {#C_FIL_02_02}

```
path ──► stat -c "%F|%n|%s|%Y|%A|%N" path/* path/.*
    ──► parse lines ──► [for symlinks: realpath + re-stat target]
    ──► item records + synthetic ".." (if not root)
```

## 3. Mechanisms  {#C_FIL_03}

### 3.1. Core Algorithm  {#C_FIL_03_01}

- **Listing:** one `io.popen` fork per directory; parse pipe-delimited fields; infer symlink target type via a secondary `stat`.
- **Absolute path:** consult cache → else `realpath`; on failure cache the input path as identity.
- **Permissions:** substring match on the owner triplet of the 10-char mode string.

### 3.2. Edge Cases  {#C_FIL_03_02}

- Filenames containing `|` break the parser — silently dropped.
- Shell metacharacters in paths (`"`, `$`, backtick) are not escaped — known limitation.
- `realpath` absent / non-POSIX → caching identity preserves UX (just no canonicalization).
- Broken symlink: `is_link = true`, `is_dir = false`, size as reported by `stat`.

## 4. Integration Points  {#C_FIL_04}

### 4.1. Dependencies  {#C_FIL_04_01}

- [C_SYS](./lfm_sys.concept.md) — for `exec_command_output` and locale-stable shelling.

### 4.2. API Surface  {#C_FIL_04_02}

- `get_absolute_path(path)` / `clear_path_cache()`.
- `get_directory_items(path) → Item[]`.
- `check_permissions(permissions, action)`.
- `get_basename(path)`.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initialized from existing codebase via onboard procedure |
