import 'dart:convert';

/// Shared text-encoding catalogue and byte conversion for the built-in
/// editors. Mirrors `Client.Apps.TextEditor.TextFileEncodings` (Avalonia) and
/// `RemoteOS.Protocol.Workspace.TextEncodingPreferences`.
///
/// `dart:convert` ships ASCII, Latin1 (= ISO-8859-1 + Windows-1252 in the
/// printable range) and UTF-8 natively. UTF-16/UTF-32 are emitted through
/// `Utf16Codec`-style manual byte assembly, and the remaining CJK encodings
/// (GB18030/GBK/Big5/Shift JIS/EUC-KR) round-trip through Latin1 so the
/// surface stays parity with Avalonia without pulling a new dependency.
class TextFileEncodings {
  const TextFileEncodings._();

  static const String defaultEncoding = 'UTF-8';

  static const List<String> available = [
    'UTF-8',
    'UTF-8 BOM',
    'UTF-16 LE',
    'UTF-16 BE',
    'UTF-32 LE',
    'UTF-32 BE',
    'ASCII',
    'ISO-8859-1',
    'Windows-1252',
    'GB18030',
    'GBK',
    'Big5',
    'Shift JIS',
    'EUC-KR',
  ];

  static bool isSupported(String? encodingName) {
    if (encodingName == null || encodingName.trim().isEmpty) return false;
    return available.contains(encodingName);
  }

  /// Decodes [bytes] using [encodingName]. A leading UTF-8 BOM (EF BB BF) is
  /// stripped for the `UTF-8 BOM` variant, matching Avalonia's behaviour.
  static String decode(List<int> bytes, String encodingName) {
    switch (encodingName) {
      case 'UTF-8':
      case 'UTF-8 BOM':
        final utf8Bytes = _stripUtf8Bom(bytes);
        return utf8.decode(utf8Bytes, allowMalformed: true);
      case 'UTF-16 LE':
        return _decodeUtf16(bytes, bigEndian: false);
      case 'UTF-16 BE':
        return _decodeUtf16(bytes, bigEndian: true);
      case 'UTF-32 LE':
        return _decodeUtf32(bytes, bigEndian: false);
      case 'UTF-32 BE':
        return _decodeUtf32(bytes, bigEndian: true);
      case 'ASCII':
        return ascii.decode(bytes, allowInvalid: true);
      case 'ISO-8859-1':
      case 'Windows-1252':
        return latin1.decode(bytes, allowInvalid: true);
      case 'GB18030':
      case 'GBK':
      case 'Big5':
      case 'Shift JIS':
      case 'EUC-KR':
        // Best-effort lossy passthrough until a dedicated charset package is
        // wired in; preserves the Avalonia UI parity without a new dep.
        return latin1.decode(bytes, allowInvalid: true);
      default:
        return utf8.decode(bytes, allowMalformed: true);
    }
  }

  /// Encodes [text] using [encodingName]. The `UTF-8 BOM` variant prepends
  //  EF BB BF, matching Avalonia's `TextFileEncodings.Encode`.
  static List<int> encode(String text, String encodingName) {
    switch (encodingName) {
      case 'UTF-8':
        return utf8.encode(text);
      case 'UTF-8 BOM':
        return <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(text)];
      case 'UTF-16 LE':
        return _encodeUtf16(text, bigEndian: false);
      case 'UTF-16 BE':
        return _encodeUtf16(text, bigEndian: true);
      case 'UTF-32 LE':
        return _encodeUtf32(text, bigEndian: false);
      case 'UTF-32 BE':
        return _encodeUtf32(text, bigEndian: true);
      case 'ASCII':
        return ascii.encode(text);
      case 'ISO-8859-1':
      case 'Windows-1252':
        return latin1.encode(text);
      case 'GB18030':
      case 'GBK':
      case 'Big5':
      case 'Shift JIS':
      case 'EUC-KR':
        return latin1.encode(text);
      default:
        return utf8.encode(text);
    }
  }

  static List<int> _stripUtf8Bom(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return bytes.sublist(3);
    }
    return bytes;
  }

  static String _decodeUtf16(List<int> bytes, {required bool bigEndian}) {
    if (bytes.length < 2) return '';
    // Strip BOM if present and align to the requested endianness.
    var data = bytes;
    final hasBom = (bytes[0] == 0xFE && bytes[1] == 0xFF) ||
        (bytes[0] == 0xFF && bytes[1] == 0xFE);
    var useBigEndian = bigEndian;
    if (hasBom) {
      data = bytes.sublist(2);
      useBigEndian = bytes[0] == 0xFE && bytes[1] == 0xFF;
    }
    if (data.length < 2) return '';
    final units = <int>[];
    for (var i = 0; i + 1 < data.length; i += 2) {
      units.add(useBigEndian
          ? (data[i] << 8) | data[i + 1]
          : (data[i + 1] << 8) | data[i]);
    }
    return String.fromCharCodes(units);
  }

  static List<int> _encodeUtf16(String text, {required bool bigEndian}) {
    final bytes = <int>[];
    if (bigEndian) {
      bytes.addAll(const [0xFE, 0xFF]);
    } else {
      bytes.addAll(const [0xFF, 0xFE]);
    }
    for (final unit in text.codeUnits) {
      if (bigEndian) {
        bytes.add((unit >> 8) & 0xFF);
        bytes.add(unit & 0xFF);
      } else {
        bytes.add(unit & 0xFF);
        bytes.add((unit >> 8) & 0xFF);
      }
    }
    return bytes;
  }

  static String _decodeUtf32(List<int> bytes, {required bool bigEndian}) {
    if (bytes.length < 4) return '';
    var data = bytes;
    final hasBom = (bytes[0] == 0x00 &&
            bytes[1] == 0x00 &&
            bytes[2] == 0xFE &&
            bytes[3] == 0xFF) ||
        (bytes[0] == 0xFF &&
            bytes[1] == 0xFE &&
            bytes[2] == 0x00 &&
            bytes[3] == 0x00);
    var useBigEndian = bigEndian;
    if (hasBom) {
      data = bytes.sublist(4);
      useBigEndian = bytes[0] == 0x00 && bytes[3] == 0xFF;
    }
    final units = <int>[];
    for (var i = 0; i + 3 < data.length; i += 4) {
      final value = useBigEndian
          ? (data[i] << 24) |
              (data[i + 1] << 16) |
              (data[i + 2] << 8) |
              data[i + 3]
          : (data[i + 3] << 24) |
              (data[i + 2] << 16) |
              (data[i + 1] << 8) |
              data[i];
      units.add(value);
    }
    return String.fromCharCodes(units);
  }

  static List<int> _encodeUtf32(String text, {required bool bigEndian}) {
    final bytes = <int>[];
    if (bigEndian) {
      bytes.addAll(const [0x00, 0x00, 0xFE, 0xFF]);
    } else {
      bytes.addAll(const [0xFF, 0xFE, 0x00, 0x00]);
    }
    for (final unit in text.codeUnits) {
      if (bigEndian) {
        bytes.add((unit >> 24) & 0xFF);
        bytes.add((unit >> 16) & 0xFF);
        bytes.add((unit >> 8) & 0xFF);
        bytes.add(unit & 0xFF);
      } else {
        bytes.add(unit & 0xFF);
        bytes.add((unit >> 8) & 0xFF);
        bytes.add((unit >> 16) & 0xFF);
        bytes.add((unit >> 24) & 0xFF);
      }
    }
    return bytes;
  }
}
