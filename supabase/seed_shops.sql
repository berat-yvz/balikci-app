-- Balıkçı dükkanları seed verisi — Supabase Dashboard > SQL Editor'da çalıştır.
-- İstanbul ve çevresi gerçekçi konumlarla 15 kayıt.
-- Önce shops tablosunun mevcut olduğundan emin ol:
-- CREATE TABLE IF NOT EXISTS public.shops (
--   id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
--   name TEXT NOT NULL,
--   lat DOUBLE PRECISION NOT NULL,
--   lng DOUBLE PRECISION NOT NULL,
--   type TEXT NOT NULL CHECK (type IN ('balikci_dukkani','olta_malzemesi','tekne_kiralama','balikci_barina','nalbur')),
--   phone TEXT,
--   hours TEXT,
--   added_by UUID REFERENCES public.users(id),
--   verified BOOLEAN DEFAULT false,
--   created_at TIMESTAMPTZ DEFAULT now()
-- );

INSERT INTO public.shops (name, lat, lng, type, phone, hours, verified) VALUES
  ('Kumkapı Balıkçı Çarşısı',         41.0060, 28.9577, 'balikci_dukkani',   '+90 212 518 1234', '06:00-20:00', true),
  ('Karaköy Balık Hali',               41.0235, 28.9745, 'balikci_dukkani',   '+90 212 293 5678', '05:00-18:00', true),
  ('Olta & Takım — Kadıköy',           40.9900, 29.0238, 'olta_malzemesi',    '+90 216 345 9876', '09:00-21:00', true),
  ('Beşiktaş Balık Pazarı',            41.0430, 29.0060, 'balikci_dukkani',   '+90 212 227 4422', '06:00-19:00', true),
  ('Sirkeci Olta Malzemeleri',          41.0140, 28.9760, 'olta_malzemesi',    '+90 212 512 7700', '08:30-21:00', false),
  ('Üsküdar Tekne Kiralama',           41.0228, 29.0148, 'tekne_kiralama',    '+90 216 553 1100', '07:00-20:00', true),
  ('Avcılar Balıkçı Barınağı',         40.9800, 28.7225, 'balikci_barina',    null,               '24 saat',     true),
  ('Florya Olta & Takım',              40.9782, 28.7862, 'olta_malzemesi',    '+90 212 663 2200', '09:00-22:00', false),
  ('Sarıyer Balıkçı Çarşısı',          41.1651, 29.0488, 'balikci_dukkani',   '+90 212 242 3344', '05:30-18:00', true),
  ('Bebek İskele Malzemeleri',          41.0768, 29.0442, 'olta_malzemesi',    '+90 212 265 1199', '10:00-22:00', false),
  ('Pendik Tekne Kiralama',            40.8750, 29.2367, 'tekne_kiralama',    '+90 216 390 5500', '06:00-21:00', true),
  ('Maltepe Balıkçı Malzemeleri',      40.9347, 29.1389, 'olta_malzemesi',    '+90 216 457 8800', '09:00-21:00', false),
  ('Tuzla Balıkçı Barınağı',           40.8200, 29.2800, 'balikci_barina',    null,               '24 saat',     true),
  ('Arnavutköy Balık Lokantası',       41.0605, 29.0345, 'balikci_dukkani',   '+90 212 358 9911', '11:00-23:00', false),
  ('Eyüp Nalbur & Olta',               41.0480, 28.9355, 'nalbur',            '+90 212 563 4400', '08:00-20:00', false)
ON CONFLICT DO NOTHING;

-- Eklenen kayıtları doğrula:
-- SELECT id, name, type, verified FROM public.shops ORDER BY name;
