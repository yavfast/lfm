# Analysis: lfm_str

**Layer:** 0 | **File:** [lfm_str.lua](../../../lfm_str.lua) | **Depends on:** none

## Purpose

Unicode-aware string width and fixed-width padding/truncation for aligning columns in the panel view.

## Public contracts

| Function | Input | Output | Semantics |
|----------|-------|--------|-----------|
| `get_string_width(str)` | UTF-8 string or nil | integer cells | 2 for CJK / fullwidth / emoji, 1 otherwise, nil → 0 |
| `pad_string(str, width, align_left)` | string, non-negative width, bool | fixed-width string | Pads with spaces; truncates with trailing `~` if too long |

## UTF-8 classification

Byte-range decoding:
- `0xC2..0xDF` — 2-byte (Latin-1 Supplement etc.): width 1.
- `0xE0..0xEF` — 3-byte: decode codepoint; width 2 if in CJK/fullwidth/hangul ranges, else 1.
- `0xF0..0xF7` — 4-byte (emoji, supplementary plane): width 2.
- Otherwise — 1 byte, width 1.

Wide-character ranges: Hangul Jamo (`U+1100-115F`), CJK (`U+2E80-9FFF`), Hangul Syllables (`U+AC00-D7A3`), CJK Compat (`U+F900-FAFF`), various fullwidth blocks.

## Truncation rule

If `get_string_width(str) > width`:
- If `width <= 1` → return `"~"`.
- Else iterate characters via `[^\128-\191][\128-\191]*` regex; append chars while `length + 1 < width`; finish with `"~"`.

> **Known inconsistency:** the truncation loop counts **characters** (not **cells**), so a string of CJK characters may render wider than `width`. See issues.md.

## Error handling

- `nil` input → width `0`, or pad returns `string.rep(" ", width)`.
- Negative width → clamped to `0` via `math.max(0, width)`.
