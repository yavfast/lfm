# Analysis: lfm_files

**Layer:** 1 | **File:** [lfm_files.lua](../../../lfm_files.lua) | **Depends on:** lfm_sys

## Purpose

Directory listing, absolute-path resolution (with cache), permission inspection, and basename extraction.

## Public contracts

| Function | Input | Output | Notes |
|----------|-------|--------|-------|
| `get_absolute_path(path)` | string | absolute path string | Memoized; runs `realpath`; on failure caches `path` itself. |
| `clear_path_cache()` | — | — | Reset memoization (called on directory change). |
| `get_directory_items(path)` | directory path | array of item records | Uses `stat -c "%F|%n|%s|%Y|%A|%N"` on `path/*` and `path/.*`. |
| `check_permissions(permissions, action)` | 10-char mode string, `"read"\|"write"\|"execute"` | truthy/falsy | Uses **user** (owner) triplet at positions 2-4/5-7/8-10. |
| `get_basename(path)` | path string | last path component | Strips trailing slashes, returns last segment. |

## Item record shape

```
{
  name         : string,           -- basename only
  path         : string,           -- absolute (or root-prefixed) path
  is_dir       : boolean,          -- true if directory (follows symlinks)
  is_link      : boolean,          -- true if symbolic link
  link_target  : string | nil,     -- absolute target if is_link
  permissions  : string,           -- 10-char "-rwxrwxrwx" form
  size         : number,           -- bytes; 0 for directories
  modified     : string            -- epoch seconds (as string from stat)
}
```

When `path ~= "/"`, a synthetic `".."` entry is inserted first with `is_dir = true`.

## Symlink resolution

For each symbolic link:
1. Parse `link_info` (`'name' -> 'target'`) from `stat`'s `%N` field.
2. If target is relative, prepend `path`.
3. `realpath` the target.
4. Re-stat the resolved target to decide `is_dir`.

## Invariants

- Only owner-triplet permissions are consulted — not group/other. LFM always assumes it runs as the file owner for permission purposes.
- `"."` and `".."` produced by the glob are filtered; the synthetic `".."` (parent) is added manually.
- Permissions check returns a Lua **truthy** value (string from `match`) or `false` — do not compare `== true`.

## Error handling

- Missing/unreadable `path` → empty items array (just the synthetic `..` if applicable).
- `realpath` failure → cached as identity (original path returned).
