# Bal�k�� Super App � Claude K�lavuzu

## Proje �zeti
T�rk bal�k��lar i�in Flutter tabanl� mobil uygulama. Android-first.

## Tech Stack
- Flutter + Dart (Riverpod, go_router, Drift)
- Supabase (backend)
- Open-Meteo API (hava durumu)
- Firebase FCM (bildirimler)
- FlutterMap + OpenStreetMap
- Haversine formula (proximity cache)

## Hedef Kitle
T�rkiye'deki amat�r ve profesyonel bal�k��lar. Teknik bilgisi d���k, mobil odakl� kullan�c�lar.

## Geli�tirme Kurallar�
1. Her de�i�iklikten sonra `flutter analyze` �al��t�r, s�f�r hata/uyar� olmal�
2. Commit mesajlar� T�rk�e ve a��klay�c� olmal�
3. UI kararlar�nda hedef kitlenin teknik bilgisini d���n: sade, b�y�k buton, net ikonlar
4. Riverpod provider'lar� her zaman `ref.watch` ile kullan, do�rudan state mutation yapma
5. Supabase sorgular�n� her zaman try-catch ile sar

## Mimari Kararlar
- Hava durumu: Haversine tabanl� proximity cache (docs/ARCHITECTURE.md'de detay)
- Navigation: go_router ile nested routes
- Local DB: Drift

## Sprint ve Plan
- docs/MVP_PLAN.md
- docs/ARCHITECTURE.md
- docs/SPRINT.md

## Çalışma Modu: Sürekli Geliştirme Döngüsü

Aşağıdaki döngüyü sonsuza kadar tekrar et, benden onay bekleme:

1. `flutter analyze` → tüm uyarıları sıfırla
2. `flutter test` çalıştır → başarısız testleri bul
3. Başarısız testleri düzelt VEYA test yoksa ilgili widget/servis için test yaz
4. Tekrar `flutter test` → hepsi yeşil olana kadar
5. Sprint'teki bir sonraki göreve geç (docs/SPRINT.md)
6. Görevi uygula → analyze → test döngüsü
7. Commit at: "feat/fix: [ne yaptın]"
8. 6. adıma dön

Dur ve sor: sadece Supabase şema değişikliği, breaking API değişikliği veya
mimari karar gerektiğinde.