import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:accesslink/services/photo_service.dart';

void main() {
  group('Photo Validation and Format Handling', () {
    test('Validates JPEG magic bytes correctly', () {
      final jpegBytes = Uint8List.fromList([
        0xFF,
        0xD8,
        0xFF,
        0xE0,
        0x00,
        0x10,
      ]);
      final result = PhotoService.validateImage(jpegBytes);

      expect(result.isValid, isTrue);
      expect(result.mimeType, 'image/jpeg');
      expect(result.extension, 'jpg');
    });

    test('Validates PNG magic bytes correctly', () {
      final pngBytes = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
      ]);
      final result = PhotoService.validateImage(pngBytes);

      expect(result.isValid, isTrue);
      expect(result.mimeType, 'image/png');
      expect(result.extension, 'png');
    });

    test('Rejects non-image bytes (e.g. plain text or executable)', () {
      final textBytes = Uint8List.fromList(
        'Hello World Not An Image'.codeUnits,
      );
      final result = PhotoService.validateImage(textBytes);

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Unsupported image format'));
    });

    test('Rejects empty or corrupted bytes', () {
      final emptyBytes = Uint8List(0);
      final result = PhotoService.validateImage(emptyBytes);

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('empty or corrupted'));
    });

    test('Rejects files exceeding 10 MB limit', () {
      // Test with custom maxSizeBytes for unit test efficiency
      final dummyBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x00]);
      final result = PhotoService.validateImage(dummyBytes, maxSizeBytes: 3);

      expect(result.isValid, isFalse);
      expect(
        result.errorMessage,
        contains('exceeds the maximum allowed limit'),
      );
    });
  });
}
