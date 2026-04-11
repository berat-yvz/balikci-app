-- Check-in'de seçilen balık türleri (çoklu, isteğe bağlı).
ALTER TABLE public.checkins
ADD COLUMN IF NOT EXISTS fish_species text[] DEFAULT NULL;

COMMENT ON COLUMN public.checkins.fish_species IS 'Balık Var akışında seçilen balık türü etiketleri';
