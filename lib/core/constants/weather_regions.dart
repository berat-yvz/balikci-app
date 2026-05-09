/// Türkiye'nin 12 kıyı bölgesi koordinatları.
/// MVP_PLAN.md → M-04 Hava Durumu bölümünden alındı.
///
/// Open-Meteo istek sıklığı (weather-cache Edge Function, pg_cron):
///   • Çalışma tarifesi : her saat başı (0 * * * *)
///   • Bölge sayısı     : 12 kıyı + 39 İstanbul ilçesi = 51 bölge
///   • Her bölge        : 2 API çağrısı (forecast + marine)
///   • Saat başı toplam : 102 istek  |  günlük: ~2 448 istek
///   • Ücretsiz limit   : 10 000/gün — kullanım oranı ~%25
///   • Flutter istemcisi: Open-Meteo'ya ASLA doğrudan istek göndermez;
///     yalnızca Supabase weather_cache tablosunu okur.
const Map<String, Map<String, double>> weatherRegions = {
  'istanbul': {'lat': 41.015, 'lng': 28.979},
  'izmir': {'lat': 38.423, 'lng': 27.143},
  'antalya': {'lat': 36.896, 'lng': 30.713},
  'trabzon': {'lat': 41.005, 'lng': 39.716},
  'canakkale': {'lat': 40.144, 'lng': 26.406},
  'bodrum': {'lat': 37.034, 'lng': 27.430},
  'fethiye': {'lat': 36.621, 'lng': 29.116},
  'sinop': {'lat': 42.023, 'lng': 35.153},
  'samsun': {'lat': 41.286, 'lng': 36.330},
  'mersin': {'lat': 36.812, 'lng': 34.641},
  'mugla': {'lat': 37.215, 'lng': 28.363},
  'balikesir': {'lat': 39.649, 'lng': 27.889},
};

/// Bölge anahtarı → kullanıcıya gösterilen Türkçe ad.
/// Tek kaynak: weather_screen, daily_forecast_screen ve weather_service
/// bu sabitten beslenir — kopyası olmamalı.
const Map<String, String> weatherRegionDisplayNames = {
  'istanbul':  'İstanbul',
  'izmir':     'İzmir',
  'antalya':   'Antalya',
  'trabzon':   'Trabzon',
  'canakkale': 'Çanakkale',
  'bodrum':    'Bodrum',
  'fethiye':   'Fethiye',
  'sinop':     'Sinop',
  'samsun':    'Samsun',
  'mersin':    'Mersin',
  'mugla':     'Muğla',
  'balikesir': 'Balıkesir',
};
