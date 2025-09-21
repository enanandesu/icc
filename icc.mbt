///|
suberror ParseError String

///|
pub impl Show for ParseError with to_string(e) {
  if e is ParseError(m) {
    m
  } else {
    "Unknown parse error"
  }
}

///|
pub impl Show for ParseError with output(e, logger) {
  logger.write_string(e.to_string())
}

///|
/// Load an ICC file from disk and decode it into a key-value map containing profile metadata.
/// 
/// Parameters:
///
/// * `path` : The file system path to the ICC profile file to be loaded and
///   parsed.
///
/// Returns a `Map[String, String]` containing the parsed ICC profile metadata
/// as key-value pairs. Common keys include "description", "manufacturer",
/// "model", "colorSpace", "connectionSpace", "intent", "version", "whitepoint",
/// and others depending on the profile content.
///
/// Throws an error of type `ParseError` if the file cannot be read from disk or
/// if the ICC profile data is invalid or corrupted.
///
/// Example:
///
/// ```text
///  let profile_data = @enanandesu/icc.parse_from_file("./test/sRGB_IEC61966-2-1_black_scaled.icc")
///  inspect(profile_data.get_or_default("colorSpace", ""), content="RGB")
///  inspect(profile_data.get_or_default("creator", ""), content="")
/// ```
///
pub fn parse_from_file(path : String) -> Map[String, String] raise ParseError {
  try {
    let content = @fs.read_file_to_bytes(path)
    let buf = @buffer.new(size_hint=content.length())
    buf.write_bytes(content)
    parse_from_buffer(buf)
  } catch {
    e => raise ParseError("Failed to parse file \{path}: \{e}")
  }
}

///|
/// Parses an ICC profile file from the specified file path (alias for
/// `parse_from_file`).
pub fn parse(path : String) -> Map[String, String] raise ParseError {
  parse_from_file(path)
}

///|
/// Parses an ICC profile from a buffer containing ICC profile data.
///
/// Parameters:
///
/// * `content` : A buffer containing the raw ICC profile data to be parsed.
///
/// Returns a `Map[String, String]` containing the parsed ICC profile metadata
/// as key-value pairs. Common keys include "description", "manufacturer",
/// "model", "colorSpace", "connectionSpace", "intent", "version", "whitepoint",
/// and others depending on the profile content.
///
/// Throws an error of type `ParseError` if the ICC profile data is invalid,
/// corrupted, or does not meet the minimum size requirements.
///
/// Example:
///
/// ```text
/// // Assuming you have ICC profile data as a buffer
/// let icc_data_buffer = @buffer.new() // Your ICC profile data as buffer
/// let profile_data = @enanandesu/icc.parse_from_buffer(icc_data_buffer)
/// inspect(profile_data.get_or_default("colorSpace", ""), content="RGB")
/// ```
///
pub fn parse_from_buffer(
  content : @buffer.Buffer,
) -> Map[String, String] raise ParseError {
  parse_content(content)
}

///|
/// Parses an ICC profile from raw bytes data.
///
/// Parameters:
///
/// * `data` : The raw ICC profile data as bytes to be parsed.
///
/// Returns a `Map[String, String]` containing the parsed ICC profile metadata
/// as key-value pairs. Common keys include "description", "manufacturer",
/// "model", "colorSpace", "connectionSpace", "intent", "version", "whitepoint",
/// and others depending on the profile content.
///
/// Throws an error of type `ParseError` if the ICC profile data is invalid,
/// corrupted, or does not meet the minimum size requirements.
///
/// Example:
///
/// ```text
/// // Assuming you have ICC profile data as bytes
/// let icc_bytes = b"..." // Your ICC profile data as bytes
/// let profile_data = @enanandesu/icc.parse_from_bytes(icc_bytes)
/// inspect(profile_data.get_or_default("colorSpace", ""), content="RGB")
/// ```
///
pub fn parse_from_bytes(data : Bytes) -> Map[String, String] raise ParseError {
  let buf = @buffer.new(size_hint=data.length())
  buf.write_bytes(data)
  parse_from_buffer(buf)
}

///|
/// Parse ICC bytes carried inside a `String` (each code unit is treated as
/// raw byte data; callers must ensure the string contains the original profile
/// bytes, e.g. by using `to_unchecked_string()`).
/// 
/// Parameters:
///
/// * `data` : A string whose UTF-16 code units contain the raw ICC bytes.
///   Typical use cases are round-tripping binary data through `Bytes` ->
///   `String::from_bytes_unchecked()` (or similar) after base64 decoding.
///
/// Returns a `Map[String, String]` containing the parsed ICC metadata.
///
/// Throws `ParseError` when the string cannot be treated as ICC bytes or the
/// profile violates format constraints.
pub fn parse_from_string(data : String) -> Map[String, String] raise ParseError {
  try {
    let bytes = data.to_bytes()
    let buf = @buffer.new(size_hint=bytes.length())
    buf.write_bytes(bytes)
    parse_from_buffer(buf)
  } catch {
    e => raise ParseError("Failed to parse string content: \{e}")
  }
}

///|
fn parse_content(
  content : @buffer.Buffer,
) -> Map[String, String] raise ParseError {
  let bytes = content.to_bytes()
  let data = bytes.to_fixedarray()
  let len = data.length()
  guard len >= 132 else {
    raise ParseError("ICC profile is too small (expected at least 132 bytes)")
  }
  let cmm = describe_vendor(read_signature(data, 4))
  let platform = describe_vendor(read_signature(data, 40))
  let manufacturer = describe_vendor(read_signature(data, 48))
  let model = read_signature(data, 52)
  let creator = describe_vendor(read_signature(data, 80))
  let version_major = data[8].to_int()
  let minor_and_bugfix = data[9].to_int()
  let version_minor = (minor_and_bugfix >> 4) & 0x0F
  let version_bugfix = minor_and_bugfix & 0x0F
  let version = version_major.to_string() +
    "." +
    version_minor.to_string() +
    "." +
    version_bugfix.to_string()
  let device_class = describe_device_class(read_signature(data, 12))
  let color_space = read_signature(data, 16)
  let connection_space = read_signature(data, 20)
  let intent_value = read_u32_be(data, 64)
  let intent = intent_to_string(intent_value)
  let whitepoint = get_whitepoint(data, len)
  guard validate_tag_table(data, len) else {
    raise ParseError("ICC profile tag table is invalid")
  }
  let description = get_tag_string(data, len, "desc")
  let device_manufacturer_description = get_tag_string(data, len, "dmnd")
  let device_model_description = get_tag_string(data, len, "dmdd")
  let mut viewing_description = get_tag_string(data, len, "vued")
  if viewing_description == "" {
    viewing_description = get_tag_string(data, len, "view")
  }
  if viewing_description != "" && !is_printable_ascii(viewing_description) {
    viewing_description = ""
  }
  let copyright = get_tag_string(data, len, "cprt")
  let res : Map[String, String] = {}
  if cmm != "" {
    res["cmm"] = cmm
  }
  if color_space != "" {
    res["colorSpace"] = color_space
  }
  if connection_space != "" {
    res["connectionSpace"] = connection_space
  }
  if copyright != "" {
    res["copyright"] = copyright
  }
  if creator != "" {
    res["creator"] = creator
  }
  if description != "" {
    res["description"] = description
  }
  if device_class != "" {
    res["deviceClass"] = device_class
  }
  if device_manufacturer_description != "" {
    res["deviceManufacturerDescription"] = device_manufacturer_description
  }
  if device_model_description != "" {
    res["deviceModelDescription"] = device_model_description
  }
  res["intent"] = intent
  if manufacturer != "" {
    res["manufacturer"] = manufacturer
  }
  if model != "" {
    res["model"] = model
  }
  if platform != "" {
    res["platform"] = platform
  }
  res["version"] = version
  if viewing_description != "" && is_printable_ascii(viewing_description) {
    res["viewingConditionsDescription"] = viewing_description
  }
  if whitepoint != "" {
    res["whitepoint"] = whitepoint
  }
  res
}

///|
fn read_u32_be(data : FixedArray[Byte], offset : Int) -> Int {
  (data[offset].to_int() << 24) |
  (data[offset + 1].to_int() << 16) |
  (data[offset + 2].to_int() << 8) |
  data[offset + 3].to_int()
}

///|
fn read_s15_fixed16_be(data : FixedArray[Byte], offset : Int) -> Int {
  let mut high = data[offset].to_int()
  if high >= 128 {
    high = high - 256
  }
  (high << 24) |
  (data[offset + 1].to_int() << 16) |
  (data[offset + 2].to_int() << 8) |
  data[offset + 3].to_int()
}

///|
fn read_signature(data : FixedArray[Byte], offset : Int) -> String {
  if offset + 4 > data.length() {
    return ""
  }
  let builder = StringBuilder::new(size_hint=4)
  for i in 0..<4 {
    builder.write_char(Int::unsafe_to_char(data[offset + i].to_int()))
  }
  trim_ascii(builder.to_string())
}

///|
fn describe_device_class(code : String) -> String {
  match code {
    "" => ""
    "scnr" | "SCNR" => "Scanner"
    "mntr" | "MNTR" => "Monitor"
    "prtr" | "PRTR" => "Printer"
    "link" | "LINK" => "Link"
    "abst" | "ABST" => "Abstract"
    "spac" | "SPAC" => "Space"
    "nmcl" | "NMCL" => "Named color"
    _ => code
  }
}

///|
fn describe_vendor(code : String) -> String {
  match code {
    "" => ""
    "appl" | "APPL" => "Apple"
    "adbe" | "ADBE" => "Adobe"
    "msft" | "MSFT" => "Microsoft"
    "sunw" | "SUNW" => "Sun Microsystems"
    "sgi" | "SGI" => "Silicon Graphics"
    "tgnt" | "TGNT" => "Taligent"
    _ => code
  }
}

///|
fn is_printable_ascii(text : String) -> Bool {
  text.iter().all(ch => ch >= ' ' && ch <= '~')
}

///|
fn format_s15_fixed16(value : Int) -> String {
  let mut val = value
  let mut sign = ""
  if val < 0 {
    sign = "-"
    val = -val
  }
  let integer = val / 65536
  let remainder = val % 65536
  if remainder == 0 {
    return sign + integer.to_string()
  }
  let scaled = remainder.to_int64() * 152587890625L
  let mut frac_str = scaled.to_string()
  while frac_str.length() < 16 {
    frac_str = "0" + frac_str
  }
  let mut trim_end = frac_str.length()
  while trim_end > 0 && frac_str[trim_end - 1] == '0'.to_int() {
    trim_end = trim_end - 1
  }
  let int_str = integer.to_string()
  if trim_end == 0 {
    return sign + int_str
  }
  let builder = StringBuilder::new(size_hint=trim_end)
  for i in 0..<trim_end {
    builder.write_char(Int::unsafe_to_char(frac_str[i]))
  }
  let trimmed = builder.to_string()
  sign + int_str + "." + trimmed
}

///|
fn format_xyz_array(x : String, y : String, z : String) -> String {
  let builder = StringBuilder::new(
    size_hint=x.length() + y.length() + z.length() + 6,
  )
  builder.write_char('[')
  builder.write_string(x)
  builder.write_string(", ")
  builder.write_string(y)
  builder.write_string(", ")
  builder.write_string(z)
  builder.write_char(']')
  builder.to_string()
}

///|
fn get_tag_xyz_string(
  data : FixedArray[Byte],
  len : Int,
  target : String,
) -> String {
  let (tag_offset, tag_size) = find_tag_entry(data, len, target)
  if tag_offset < 0 || tag_size < 20 {
    return ""
  }
  if tag_offset + 20 > len {
    return ""
  }
  let tag_type = read_signature(data, tag_offset)
  if tag_type != "XYZ" {
    return ""
  }
  let x = format_s15_fixed16(read_s15_fixed16_be(data, tag_offset + 8))
  let y = format_s15_fixed16(read_s15_fixed16_be(data, tag_offset + 12))
  let z = format_s15_fixed16(read_s15_fixed16_be(data, tag_offset + 16))
  format_xyz_array(x, y, z)
}

///|
fn get_whitepoint(data : FixedArray[Byte], len : Int) -> String {
  let tag_value = get_tag_xyz_string(data, len, "wtpt")
  if tag_value != "" {
    return tag_value
  }
  let x = format_s15_fixed16(read_s15_fixed16_be(data, 68))
  let y = format_s15_fixed16(read_s15_fixed16_be(data, 72))
  let z = format_s15_fixed16(read_s15_fixed16_be(data, 76))
  format_xyz_array(x, y, z)
}

///|
fn trim_ascii(text : String) -> String {
  let mut start = 0
  let mut end = text.length()
  while start < end && is_ascii_trim_char(text[start]) {
    start = start + 1
  }
  while end > start && is_ascii_trim_char(text[end - 1]) {
    end = end - 1
  }
  if end <= start {
    return ""
  }
  let builder = StringBuilder::new(size_hint=end - start)
  for i in start..<end {
    builder.write_char(Int::unsafe_to_char(text[i]))
  }
  builder.to_string()
}

///|
fn is_ascii_trim_char(ch : Int) -> Bool {
  ch == ' '.to_int() ||
  ch == '\t'.to_int() ||
  ch == '\r'.to_int() ||
  ch == '\n'.to_int() ||
  ch == 0
}

///|
fn validate_tag_table(data : FixedArray[Byte], len : Int) -> Bool {
  let tag_table_start = 128
  if len < tag_table_start + 4 {
    return false
  }
  let tag_count = read_u32_be(data, tag_table_start)
  if tag_count < 0 {
    return false
  }
  let entries_start = tag_table_start + 4
  if entries_start >= len {
    return false
  }
  let remaining = len - entries_start
  let required = tag_count.to_int64() * 12L
  if required > remaining.to_int64() {
    return false
  }
  true
}

///|
fn get_tag_string(
  data : FixedArray[Byte],
  len : Int,
  target : String,
) -> String {
  let (tag_offset, tag_size) = find_tag_entry(data, len, target)
  if tag_offset < 0 || tag_size <= 0 {
    return ""
  }
  parse_tag_text(data, tag_offset, tag_size)
}

///|
fn find_tag_entry(
  data : FixedArray[Byte],
  len : Int,
  target : String,
) -> (Int, Int) {
  let tag_table_start = 128
  if len < tag_table_start + 4 {
    return (-1, 0)
  }
  let tag_count = read_u32_be(data, tag_table_start)
  if tag_count <= 0 {
    return (-1, 0)
  }
  let entries_start = tag_table_start + 4
  if entries_start >= len {
    return (-1, 0)
  }
  let max_entries = (len - entries_start) / 12
  if tag_count > max_entries {
    return (-1, 0)
  }
  for i in 0..<tag_count {
    let entry_offset = entries_start + i * 12
    if entry_offset + 12 > len {
      break
    }
    let signature = read_signature(data, entry_offset)
    if signature == target {
      let data_offset = read_u32_be(data, entry_offset + 4)
      let data_size = read_u32_be(data, entry_offset + 8)
      if data_offset < 0 || data_size <= 0 {
        return (-1, 0)
      }
      if data_offset + data_size > len {
        return (-1, 0)
      }
      return (data_offset, data_size)
    }
  }
  (-1, 0)
}

///|
fn parse_tag_text(data : FixedArray[Byte], offset : Int, size : Int) -> String {
  if size < 8 {
    return ""
  }
  let tag_type = read_signature(data, offset)
  match tag_type {
    "desc" => parse_desc_type(data, offset, size)
    "mluc" => parse_mluc_type(data, offset, size)
    "text" => parse_text_type(data, offset, size)
    _ => parse_text_type(data, offset, size)
  }
}

///|
fn parse_desc_type(data : FixedArray[Byte], offset : Int, size : Int) -> String {
  if size < 12 {
    return ""
  }
  let ascii_length = read_u32_be(data, offset + 8)
  if ascii_length <= 0 || ascii_length > size - 12 {
    return ""
  }
  let mut actual_length = ascii_length
  if actual_length > 0 && data[offset + 12 + actual_length - 1].to_int() == 0 {
    actual_length = actual_length - 1
  }
  trim_ascii(ascii_slice_to_string(data, offset + 12, actual_length))
}

///|
fn parse_text_type(data : FixedArray[Byte], offset : Int, size : Int) -> String {
  if size <= 8 {
    return ""
  }
  trim_ascii(ascii_slice_to_string(data, offset + 8, size - 8))
}

///|
fn ascii_slice_to_string(
  data : FixedArray[Byte],
  start : Int,
  length : Int,
) -> String {
  if length <= 0 || start + length > data.length() {
    return ""
  }
  let builder = StringBuilder::new(size_hint=length)
  for i in 0..<length {
    builder.write_char(Int::unsafe_to_char(data[start + i].to_int()))
  }
  builder.to_string()
}

///|
fn parse_mluc_type(data : FixedArray[Byte], offset : Int, size : Int) -> String {
  if size < 16 {
    return ""
  }
  let record_count = read_u32_be(data, offset + 8)
  let record_size = read_u32_be(data, offset + 12)
  if record_count <= 0 || record_size < 12 {
    return ""
  }
  if offset + 16 + record_count * record_size > offset + size {
    return ""
  }
  let records_base = offset + 16
  let mut first_non_empty = ""
  for i in 0..<record_count {
    let record_offset = records_base + i * record_size
    if record_offset + 12 > offset + size {
      continue
    }
    let length = read_u32_be(data, record_offset + 4)
    let text_offset = read_u32_be(data, record_offset + 8)
    if length <= 0 {
      continue
    }
    let absolute_start = offset + text_offset
    if absolute_start < offset + 16 || absolute_start + length > offset + size {
      continue
    }
    let text = trim_ascii(utf16be_slice_to_string(data, absolute_start, length))
    if text == "" {
      continue
    }
    let lang = ascii_slice_to_string(data, record_offset, 2)
    if lang == "en" {
      return text
    }
    if first_non_empty == "" {
      first_non_empty = text
    }
  }
  first_non_empty
}

///|
fn utf16be_slice_to_string(
  data : FixedArray[Byte],
  start : Int,
  length : Int,
) -> String {
  if length <= 1 || start + length > data.length() {
    return ""
  }
  let mut i = 0
  let builder = StringBuilder::new(size_hint=length / 2)
  while i + 1 < length {
    let high = data[start + i].to_int()
    let low = data[start + i + 1].to_int()
    let code_unit = (high << 8) | low
    if code_unit == 0 {
      i = i + 2
      continue
    }
    if code_unit >= 0xD800 && code_unit <= 0xDBFF {
      if i + 3 >= length {
        break
      }
      let next_high = data[start + i + 2].to_int()
      let next_low = data[start + i + 3].to_int()
      let next_code = (next_high << 8) | next_low
      if next_code < 0xDC00 || next_code > 0xDFFF {
        i = i + 2
        continue
      }
      let code_point = 0x10000 +
        ((code_unit - 0xD800) << 10) +
        (next_code - 0xDC00)
      builder.write_char(Int::unsafe_to_char(code_point))
      i = i + 4
      continue
    }
    if code_unit >= 0xDC00 && code_unit <= 0xDFFF {
      i = i + 2
      continue
    }
    builder.write_char(Int::unsafe_to_char(code_unit))
    i = i + 2
  }
  builder.to_string()
}

///|
fn intent_to_string(value : Int) -> String {
  match value {
    0 => "Perceptual"
    1 => "Relative"
    2 => "Saturation"
    3 => "Absolute"
    _ => "Unknown(" + value.to_string() + ")"
  }
}
