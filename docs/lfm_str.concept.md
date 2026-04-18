# String Width & Padding  {#C_STR}

> **Code:** C_STR
> **Status:** active
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
> **Author:** onboard
>
> **Depends on:** none
> **Used by:** [C_LFM](./lfm.concept.md)
> **Specification:** [SP_STR](./lfm_str.sp.md)
> **Plan:** [lfm_str.plan.md](./lfm_str.plan.md)
>
> Unicode-aware string-width computation and fixed-width padding for column alignment in the panel view.

## 1. Philosophy  {#C_STR_01}

### 1.1. Core Principle  {#C_STR_01_01}

Lua's `#s` returns byte length — useless for terminal column alignment when filenames contain non-ASCII characters. `lfm_str` provides a minimal, dependency-free reimplementation of "East Asian Width" classification sufficient for panel rendering.

### 1.2. Design Constraints  {#C_STR_01_02}

- No external Unicode tables — inline ranges.
- Width ∈ {1, 2} — no zero-width characters or combining marks.
- Truncation uses a trailing `~` as a visual overflow marker.

## 2. Domain Model  {#C_STR_02}

### 2.1. Key Entities  {#C_STR_02_01}

- **UTF-8 byte stream** — input to width computation.
- **Display cell** — 1 or 2 terminal columns per codepoint.

### 2.2. Data Flows  {#C_STR_02_02}

String → byte walk → per-codepoint cell count → sum → width. For padding, width → `space * (target - width)` prepended or appended.

## 3. Mechanisms  {#C_STR_03}

### 3.1. Core Algorithm  {#C_STR_03_01}

Byte-level UTF-8 decode:
- `0x00..0x7F` — ASCII, width 1.
- `0xC2..0xDF` — 2-byte, width 1.
- `0xE0..0xEF` — 3-byte, decode codepoint, check wide ranges.
- `0xF0..0xF7` — 4-byte, width 2 (emoji / supplementary).

### 3.2. Edge Cases  {#C_STR_03_02}

- `nil` or empty string → width 0 / blank padding.
- Negative width → clamped to 0.
- String wider than target → truncate and append `~`.
- `width <= 1` with over-wide input → return lone `~`.

## 4. Integration Points  {#C_STR_04}

### 4.1. Dependencies  {#C_STR_04_01}

None.

### 4.2. API Surface  {#C_STR_04_02}

- `get_string_width(str)` → number.
- `pad_string(str, width, align_left)` → string of exact width.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initialized from existing codebase via onboard procedure |
