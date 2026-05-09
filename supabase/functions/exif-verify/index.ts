// NOT: exif-verify fonksiyonu fish_log modülü kaldırıldığı için pasife alındı.
// Supabase Dashboard'dan trigger/webhook bağlantısı kesilmeli.
// Fonksiyon dosyası referans olarak korunmaktadır.
//
// Önceki sürüm check-in fotoğrafları için EXIF doğrulaması yapıyordu;
// yeniden aktifleştirmek için git geçmişindeki implementasyona bakın.

Deno.serve((_req) =>
  new Response(JSON.stringify({ status: 'disabled' }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  }),
);
