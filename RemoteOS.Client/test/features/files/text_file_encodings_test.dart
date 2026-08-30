import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remoteos_client/features/files/text_file_encodings.dart';

void main() {
  const channel = MethodChannel('charset_converter');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final arguments = call.arguments as Map<Object?, Object?>;
      final charset = arguments['charset'];

      switch (call.method) {
        case 'encode':
          expect(charset, _gbkCharsetName);
          return Uint8List.fromList(const [0xD6, 0xD0]);
        case 'decode':
          expect(charset, _gbkCharsetName);
          expect(arguments['data'], Uint8List.fromList(const [0xD6, 0xD0]));
          return '中';
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('encodes and decodes GBK through the native desktop codec', () async {
    expect(await TextFileEncodings.encode('中', 'GBK'), [0xD6, 0xD0]);
    expect(await TextFileEncodings.decode([0xD6, 0xD0], 'GBK'), '中');
  });

  test('keeps UTF-8 conversion in Dart without invoking the platform codec',
      () async {
    expect(await TextFileEncodings.encode('中', 'UTF-8'), [0xE4, 0xB8, 0xAD]);
    expect(await TextFileEncodings.decode([0xE4, 0xB8, 0xAD], 'UTF-8'), '中');
  });
}

String get _gbkCharsetName => Platform.isWindows ? 'gb2312' : 'GBK';
