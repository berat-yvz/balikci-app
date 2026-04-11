import 'dart:typed_data';

import 'package:balikci_app/core/utils/avatar_image_prepare.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

void main() {
  test('avatar sıkıştırma çıktıyı 2MB sınırının altında tutar', () async {
    final im = img.Image(width: 1600, height: 1600);
    img.fill(im, color: img.ColorRgb8(40, 120, 200));
    final raw = Uint8List.fromList(img.encodeJpg(im, quality: 95));

    final out = await prepareAvatarUploadBytes(
      XFile.fromData(
        raw,
        name: 'photo.jpg',
        mimeType: 'image/jpeg',
      ),
    );

    expect(out.length, lessThanOrEqualTo(kAvatarMaxUploadBytes));
    expect(out.length, greaterThan(500));
  });
}
