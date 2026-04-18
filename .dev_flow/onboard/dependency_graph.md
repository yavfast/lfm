# Dependency Graph

Edges below are `require(...)` calls inside each module.

```
lfm.lua         -> lfm_sys, lfm_files, lfm_scr, lfm_view, lfm_str, lfm_terminal
lfm_view.lua    -> lfm_files, lfm_scr, lfm_sys
lfm_terminal.lua-> lfm_scr
lfm_files.lua   -> lfm_sys
lfm_sys.lua     -> (none)
lfm_scr.lua     -> (none)
lfm_str.lua     -> (none)
```

No circular dependencies. No imports from outside the project.
