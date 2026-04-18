# Implementation Plan: File System Operations  {#PL_FIL}

> **Code:** PL_FIL
> **Status:** completed
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Concept:** [C_FIL](./lfm_files.concept.md)
> **Specification:** [SP_FIL](./lfm_files.sp.md)
> **Depends on plans:** [PL_SYS](./lfm_sys.plan.md)
> **Used by plans:** [PL_VIW](./lfm_view.plan.md), [PL_LFM](./lfm.plan.md)
>
> Fully implemented in [lfm_files.lua](../lfm_files.lua).

## Goal

Provide a single `get_directory_items(path) → Item[]` entry point the UI can call without touching `stat` / `realpath`.

## Technology Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Directory listing | `stat -c "%F|%n|%s|%Y|%A|%N" path/* path/.*` | Single fork per directory; deterministic fields; reveals symlink target |
| Path canonicalization | `realpath` + in-memory cache | Cheap memoization; cache invalidated on directory change |
| Glob hidden files | `path/.*` | Includes dotfiles alongside visible entries |
| Permissions model | Owner triplet only | Matches single-user desktop use; no uid/gid logic needed |

## Progress

- [x] Phase 1 — `get_absolute_path` + cache
- [x] Phase 2 — `get_directory_items` with symlink resolution
- [x] Phase 3 — `check_permissions` and `get_basename`

## Phases

### Phase 1 — Absolute-path cache (`lfm_files.lua`) [DONE]

**Implements:** [SP_FIL_02_01](./lfm_files.sp.md#SP_FIL_02_01), [SP_FIL_02_02](./lfm_files.sp.md#SP_FIL_02_02)

Module-level table `abs_path_cache`; `get_absolute_path` consults it before shelling out; `clear_path_cache` resets to `{}`.

### Phase 2 — Directory listing with symlink resolution [DONE]

**Implements:** [SP_FIL_02_03](./lfm_files.sp.md#SP_FIL_02_03)

- Inject synthetic `..` for non-root.
- Parse `stat` glob output line-by-line.
- For each link, parse `'name' -> 'target'`, resolve to absolute, re-stat to determine `is_dir`.

### Phase 3 — Permissions and basename [DONE]

**Implements:** [SP_FIL_02_04](./lfm_files.sp.md#SP_FIL_02_04), [SP_FIL_02_05](./lfm_files.sp.md#SP_FIL_02_05)

Substring-match positions 2-4 / 5-7 / 8-10 in the 10-char mode string.

## Backlog

- [ ] Cache directory listings (with invalidation via mtime) to make Ctrl+R faster.
- [ ] Add `is_executable` boolean to Item struct — currently recomputed in the renderer.
- [ ] Symlink resolution now runs 2 extra forks per link (`readlink` + `stat` target). Batch symlink resolution for directories with many links, or fold back into the main `stat` call via `%N` parsing when filenames are safe.

## Completed (after onboard)

- [x] Escape shell metacharacters in `path` — every invocation now uses `lfm_sys.shell_quote`.
- [x] Support filenames containing `|`, `'`, `$`, spaces — stat output switched to NUL-separated fields.
- [x] Fix `check_permissions` — read/write/execute were examining owner/group/other triplets (mixed up); all three now consult the owner triplet correctly.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initialized from existing codebase via onboard procedure |
| 2026-04-18 | Applied post-onboard fixes: shell escaping, NUL-separated stat, check_permissions owner-triplet correction. |
