# ICC Profile Parser for MoonBit

This package provides a lightweight ICC profile inspector written in MoonBit. It loads raw ICC data, performs structural validation, and exposes key metadata such as version, device class, color spaces, white point, readable descriptions, and more.

---

## Features

- Extracts ICC header information (CMM, platform, manufacturer, model, version,  intent, white point, etc.).
- Decodes common text tags (`desc`, `dmnd`, `dmdd`, `vued`, `view`, `cprt`).
- Handles `desc`, `text`, `mluc` tag data (UTF-16BE aware and defensive against malformed surrogate pairs).
- Expands common four-character signatures to human-friendly labels (`mntr -> Monitor`, `msft -> Microsoft`, ...).
- Defensive parsing: validates profile size, tag table bounds, filters non-printable viewing descriptions, and returns descriptive `ParseError` values.

---

## Installation

```bash
moon update
moon add enanandesu/icc
```
---

## Public API

| Function | Description |
| -------- | ----------- |
| `parse(path)` | Backwards-compatible alias for `parse_from_file`. |
| `parse_from_file(path)` | Read an ICC file from disk and return metadata. |
| `parse_from_bytes(bytes)` | Parse an ICC profile represented as `Bytes`. |
| `parse_from_buffer(buffer)` | Parse ICC data already staged in `@buffer.Buffer`. |
| `parse_from_string(text)` | Parse ICC bytes carried inside a `String`; every UTF-16 code unit must match the original byte. |

The return value is always `Map[String, String]` and each function may raise `ParseError`. Typical keys include `cmm`, `platform`, `manufacturer`, `model`, `version`, `deviceClass`, `colorSpace`, `connectionSpace`, `intent`, `whitepoint`, `description`, `deviceManufacturerDescription`, `deviceModelDescription`, and `viewingConditionsDescription`.

---

## Usage Examples

### Parse from file

```text
let profile = @enanandesu/icc.parse_from_file("./test/sRGB_IEC61966-2-1_black_scaled.icc")
inspect(profile.get_or_default("colorSpace", ""), content="RGB")
```

### Parse from bytes

```text
let bytes = @fs.read_file_to_bytes("./test/sRGB_ICC_v4_Appearance.icc")
let profile = @enanandesu/icc.parse_from_bytes(bytes)
inspect(profile.get_or_default("version", ""), content="4.3.0")
```

### Parse from buffer

```text
let bytes = @fs.read_file_to_bytes("./test/D65_XYZ.icc")
let buf = @buffer.new(size_hint=bytes.length())
buf.write_bytes(bytes)
let profile = @enanandesu/icc.parse_from_buffer(buf)
inspect(profile.get_or_default("creator", ""), content="none")
```

### Parse from raw-string bytes

```text
let bytes = @fs.read_file_to_bytes("./test/D65_XYZ.icc")
let text = bytes.to_unchecked_string()  // UTF-16 code units equal to raw bytes
let profile = @enanandesu/icc.parse_from_string(text)
inspect(profile.get_or_default("creator", ""), content="none")
```

> **Note:** `parse_from_string` expects the string to store the original ICC
> bytes in its UTF-16 code units. Supplying a normal UTF-8 string (for example,
> "Hello UTF-8 text!") will cause parsing to fail with `ParseError`.

---

## Error Handling

`ParseError` explains the failure reason. Examples:

- `ICC profile is too small (expected at least 132 bytes)` - profile truncated.
- `ICC profile tag table is invalid` - tag directory would extend past buffer.
- `Failed to parse string content: ...` - converting the provided string into bytes failed before parsing.

Use `try`/`catch` to handle individual cases as needed.

---

## License

Apache-2.0
