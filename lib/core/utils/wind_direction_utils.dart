/// Open-Meteo / yaygın meteoroloji: rüzgarın **geldiği** yön (°), 0 = Kuzey,
/// saat yönünde artar.
int normalizeWindDirectionDegrees(int degrees) {
  var d = degrees % 360;
  if (d < 0) {
    d += 360;
  }
  return d;
}

/// Sekiz ana yön (45° dilimler).
String turkishWindDirectionSector(int degrees) {
  final d = normalizeWindDirectionDegrees(degrees);
  const names = <String>[
    'Kuzey',
    'Kuzeydoğu',
    'Doğu',
    'Güneydoğu',
    'Güney',
    'Güneybatı',
    'Batı',
    'Kuzeybatı',
  ];
  final i = ((d + 22.5) / 45).floor() % 8;
  return names[i];
}

/// Tek tip kullanıcı metni: `Güneydoğu · 164°`
String formatWindDirectionTurkish(int? degrees) {
  if (degrees == null) {
    return '—';
  }
  final d = normalizeWindDirectionDegrees(degrees);
  return '${turkishWindDirectionSector(d)} · $d°';
}

/// İstanbul kıyısı için bilgilendirme: güney ve güneybatı dilimleri (Lodos bandına yakın).
bool isSoutherlyWindCoastalAdvisory(int? degrees) {
  if (degrees == null) {
    return false;
  }
  final d = normalizeWindDirectionDegrees(degrees);
  return d >= 157.5 && d < 247.5;
}
