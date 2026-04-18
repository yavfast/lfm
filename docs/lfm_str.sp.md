# String Width & Padding — Specification  {#SP_STR}

> **Code:** SP_STR
> **Status:** active
> **Created:** 2026-04-18
> **Updated:** 2026-04-18
>
> **Concept:** [C_STR](./lfm_str.concept.md)
> **Depends on specs:** none
> **Used by specs:** [SP_LFM](./lfm.sp.md)
> **Plan:** [lfm_str.plan.md](./lfm_str.plan.md)

## 01. Data Structures  {#SP_STR_01}

### 01_01. Wide-character ranges  {#SP_STR_01_01}

Codepoints counted as 2 display cells:

| Block | Range |
|-------|-------|
| Hangul Jamo | U+1100..U+115F |
| CJK (Unified + Extension A + misc) | U+2E80..U+9FFF |
| Hangul Syllables | U+AC00..U+D7A3 |
| CJK Compatibility | U+F900..U+FAFF |
| Vertical forms | U+FE10..U+FE19 |
| CJK Compatibility Forms | U+FE30..U+FE6F |
| Fullwidth forms | U+FF00..U+FF60 |
| Fullwidth signs | U+FFE0..U+FFE6 |

4-byte UTF-8 codepoints (supplementary plane, most emoji) are unconditionally width 2.

## 02. Contracts  {#SP_STR_02}

### 02_01. get_string_width  {#SP_STR_02_01}

Input:
| Parameter | Type | Required | Constraints |
|-----------|------|----------|-------------|
| str | string \| nil | no | Any UTF-8 bytes or nil |

Output:
| Field | Type | Description |
|-------|------|-------------|
| width | integer ≥ 0 | Number of display cells |

Errors: none — malformed UTF-8 is tolerated by treating orphan bytes as 1 cell.

Processing logic (pseudocode):

    FUNCTION get_string_width(str):
        IF str is nil: return 0
        width = 0; i = 1
        WHILE i <= #str:
            b = byte(str, i)
            IF b in 0xE0..0xEF:
                cp = decode 3-byte
                width += 2 IF cp in wide_ranges ELSE 1
                i += 3
            ELSE IF b in 0xF0..0xF7:
                width += 2; i += 4
            ELSE IF b in 0xC2..0xDF:
                width += 1; i += 2
            ELSE:
                width += 1; i += 1
        return width

### 02_02. pad_string  {#SP_STR_02_02}

Input:
| Parameter | Type | Required | Constraints |
|-----------|------|----------|-------------|
| str | string \| nil | no | any; nil treated as "" |
| width | integer | yes | clamped to ≥ 0 |
| align_left | boolean | yes | true = spaces on right; false = spaces on left |

Output: string of exact target width (except when truncating — see below).

Rules:
- `str == nil or ""` → return `string.rep(" ", max(0, width))`.
- `get_string_width(str) > width`:
  - If `width <= 1` → `"~"`.
  - Else iterate chars (byte-level regex `[^\x80-\xBF][\x80-\xBF]*`), append while `length + 1 < width`, then append `"~"`.
- Otherwise pad with `width - current_width` spaces on the chosen side.

Errors:
| Code | Condition | Guidance |
|------|-----------|----------|
| n/a | — | No errors raised |

## 03. Validation Rules  {#SP_STR_03}

### 03_01. Input Validation  {#SP_STR_03_01}

- Both functions accept `nil` gracefully.
- `width < 0` is clamped, not rejected.

## 05. Verification Criteria  {#SP_STR_05}

### 05_01. Functional Expectations  {#SP_STR_05_01}

| Contract | Scenario | Input | Expected |
|----------|----------|-------|----------|
| get_string_width | nil | nil | 0 |
| get_string_width | ASCII | `"abc"` | 3 |
| get_string_width | CJK | `"中文"` | 4 |
| get_string_width | emoji | `"😀"` | 2 |
| pad_string | short left-align | `("abc", 6, true)` | `"abc   "` |
| pad_string | short right-align | `("abc", 6, false)` | `"   abc"` |
| pad_string | exact | `("abcdef", 6, true)` | `"abcdef"` |
| pad_string | overflow | `("abcdef", 4, true)` | `"abc~"` |
| pad_string | width 1 overflow | `("abc", 1, true)` | `"~"` |
| pad_string | nil input | `(nil, 4, true)` | `"    "` |

### 05_02. Invariant Checks  {#SP_STR_05_02}

| Invariant | Verification method |
|-----------|-------------------|
| Output never `nil` | Unit-test nil/empty inputs |
| No crash on malformed UTF-8 | Fuzz with random bytes |

### 05_04. Edge Cases and Boundaries  {#SP_STR_05_04}

| Case | Input | Expected |
|------|-------|----------|
| Negative width | `("abc", -5, true)` | `""` |
| Width 0 | `("abc", 0, true)` | `""` |

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initialized from existing codebase via onboard procedure |
