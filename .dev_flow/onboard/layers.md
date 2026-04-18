# Dependency Layers

| Layer | Module | Depends on |
|-------|--------|------------|
| 0 | `lfm_sys` | — |
| 0 | `lfm_scr` | — |
| 0 | `lfm_str` | — |
| 1 | `lfm_files` | lfm_sys |
| 1 | `lfm_terminal` | lfm_scr |
| 2 | `lfm_view` | lfm_files, lfm_scr, lfm_sys |
| 3 | `lfm` (entry) | all of the above |

Layer 0 modules are independent — safe to analyze in parallel.
Layer 3 has no dependents (it is the program entry point).
