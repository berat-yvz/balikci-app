import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

/// Supabase avatar / fish-photos ile uyumlu üst boyut (bkz. migration, ARCHITECTURE).
const int kAvatarMaxUploadBytes = 2 * 1024 * 1024;

const int _kMaxEdgePx = 1024;

/// Galeriden seçilen dosyayı JPEG olarak küçültür; 2MB altına indirmeye çalışır.
Future<Uint8List> prepareAvatarUploadBytes(XFile picked) async {
  Uint8List? out;

  if (!kIsWeb && picked.path.isNotEmpty) {
    out = await _compressWithFlutterImageCompress(picked.path);
  }

  out ??= await _compressWithImagePackage(await picked.readAsBytes());

  if (out.length > kAvatarMaxUploadBytes) {
    throw Exception(
      'Fotoğraf sıkıştırıldıktan sonra hâlâ çok büyük. Başka bir fotoğraf seçin.',
    );
  }
  return out;
}

Future<Uint8List?> _compressWithFlutterImageCompress(String path) async {
  try {
    var q = 88;
    while (q >= 38) {
      final bytes = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: _kMaxEdgePx,
        minHeight: _kMaxEdgePx,
        quality: q,
        format: CompressFormat.jpeg,
      );
      if (bytes == null) return null;
      if (bytes.length <= kAvatarMaxUploadBytes) return bytes;
      q -= 10;
    }
    return await FlutterImageCompress.compressWithFile(
      path,
      minWidth: 640,
      minHeight: 640,
      quality: 48,
      format: CompressFormat.jpeg,
    );
  } catch (_) {
    return null;
  }
}

Future<Uint8List> _compressWithImagePackage(Uint8List raw) async {
  final decoded = img.decodeImage(raw);
  if (decoded == null) {
    throw Exception(
      'Fotoğraf açılamadı. JPG veya PNG seçtiğinizden emin olun.',
    );
  }

  var image = img.bakeOrientation(decoded);

  void shrinkToMaxEdge(int maxEdge) {
    final w = image.width;
    final h = image.height;
    if (w <= maxEdge && h <= maxEdge) return;
    if (w >= h) {
      image = img.copyResize(
        image,
        width: maxEdge,
        height: (h * maxEdge / w).round(),
        interpolation: img.Interpolation.average,
      );
    } else {
      image = img.copyResize(
        image,
        height: maxEdge,
        width: (w * maxEdge / h).round(),
        interpolation: img.Interpolation.average,
      );
    }
  }

  for (final edge in [1024, 768, 512, 384, 320]) {
    shrinkToMaxEdge(edge);
    for (var q = 86; q >= 32; q -= 8) {
      final jpg = Uint8List.fromList(img.encodeJpg(image, quality: q));
      if (jpg.length <= kAvatarMaxUploadBytes) return jpg;
    }
  }

  shrinkToMaxEdge(256);
  return Uint8List.fromList(img.encodeJpg(image, quality: 28));
}
