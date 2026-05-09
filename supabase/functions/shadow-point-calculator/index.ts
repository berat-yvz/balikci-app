// NOT: Balık günlüğü (fish_logs) modülü kaldırıldı — shadow-point-calculator
// artık fish_log_id ile çalışmıyor. Supabase Dashboard'dan ilgili webhook
// bağlantısı kesilmeli.

Deno.serve((_req) =>
  new Response(JSON.stringify({ status: 'disabled' }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  }),
);
