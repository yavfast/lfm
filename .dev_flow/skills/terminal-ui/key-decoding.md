# Key decoding (lfm_sys.get_key)

Terminals send multi-byte sequences for non-printable keys. `lfm_sys.get_key` reads the first byte with blocking `io.read(1)` and, for `\27` (ESC), pulls up to 5 more bytes using `read_with_timeout` to disambiguate.

## Sequence table

| Key | Bytes | `get_key` returns |
|-----|-------|-------------------|
| ESC alone | `\27` + timeout | `escape` |
| Up/Down/Right/Left | `\27 [ A/B/C/D` | `up` / `down` / `right` / `left` |
| PageUp/PageDown | `\27 [ 5 ~` / `\27 [ 6 ~` | `pageup` / `pagedown` |
| Home/End | `\27 [ H` / `\27 [ F` | `home` / `end` |
| Ctrl+Up/Down | `\27 [ 1 ; 5 A/B` | `ctrl_up` / `ctrl_down` |
| Ctrl+Shift+Up/Down | `\27 [ 1 ; 6 A/B` | `ctrl_shift_up` / `ctrl_shift_down` |
| F3 / F4 | `\27 O R/S` | `view` / `edit` |
| F10 | `\27 [ 2 1 ~` | `quit` |
| Enter | `\13` | `enter` |
| Tab | `\t` | `tab` |
| Ctrl+R | `\18` | `refresh` |
| Printable or unknown | single byte | the raw byte (e.g. `"a"`, `" "`) |
| Backspace | `\127` | returned as-is (consumers match `"\127"` or `"\b"`) |

## Notes

- Some terminals send `\27 [ 1 ~` for Home and `\27 [ 4 ~` for End; those are **not** currently handled — they fall through to `nil`. Add if a user reports missing keys.
- F1/F2/F5-F9/F11-F12 are not recognized — extend the `next2 == "2"` / `next2 == "O"` branches to add them.
- Printable bytes are returned as-is; callers decide whether they are commands, text, or noise.

## Reference

- VT100 escape sequences — `man 4 console_codes`
- xterm modifier encoding (`;1;2`-style) — <https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h3-PC-Style-Function-Keys>
