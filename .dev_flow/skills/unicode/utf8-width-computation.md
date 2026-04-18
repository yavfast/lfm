# UTF-8 width computation (lfm_str)

Lua strings are byte arrays. `#s` returns bytes, not characters — unusable for column alignment. `lfm_str.get_string_width` walks the UTF-8 byte stream and assigns a width of 1 or 2 cells to each codepoint.

## Algorithm

```
byte in 0x00..0x7F                        -> 1-byte, width 1
byte in 0xC2..0xDF                        -> 2-byte, width 1  (Latin-1 supplement etc.)
byte in 0xE0..0xEF                        -> 3-byte, decode codepoint:
    wide if codepoint in CJK/fullwidth/hangul ranges, else narrow
byte in 0xF0..0xF7                        -> 4-byte, width 2  (emoji, supplementary)
continuation bytes (0x80..0xBF)           -> skipped during decode
```

Codepoint for 3-byte sequence:
`cp = ((b0 * 0x1000) + (b1 * 0x40) + b2) - 0xE0 * 0x1000`  (simplified — drops the mask but works for valid UTF-8).

## Wide ranges recognized

| Block | Range |
|-------|-------|
| Hangul Jamo | `U+1100..U+115F` |
| CJK (Unified + Extensions A + compat) | `U+2E80..U+9FFF` |
| Hangul Syllables | `U+AC00..U+D7A3` |
| CJK Compatibility | `U+F900..U+FAFF` |
| Vertical forms | `U+FE10..U+FE19` |
| CJK Compatibility Forms | `U+FE30..U+FE6F` |
| Fullwidth forms | `U+FF00..U+FF60` |
| Fullwidth signs | `U+FFE0..U+FFE6` |

Emoji (mostly in supplementary plane via 4-byte sequences) are treated as width 2 without per-codepoint check — good enough for panel rendering.

## Known limitations

- No Unicode 15 ZWJ / variation-selector handling — emoji sequences with skin-tone modifiers may over-count.
- `pad_string` truncates by **character count**, not width — strings of wide characters may overflow target width by 1.
- Not aware of terminfo's `acsc` characters or combining marks.

## When to extend

If alignment misbehaves on new scripts, consult <https://www.unicode.org/Public/UNIDATA/EastAsianWidth.txt> and add the new ranges to the `if (codepoint >= ...) then` chain.
