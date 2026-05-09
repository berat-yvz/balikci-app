-- ============================================================
-- FAZ 1 — Sosyal Akış: posts tablosu
-- Çalıştırma sırası: 1/3
-- ============================================================

CREATE TABLE posts (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- Medya (zorunlu — en az bir fotoğraf olmadan post oluşturulamaz)
  photo_url            TEXT        NOT NULL,

  -- İçerik
  caption              TEXT        CHECK (char_length(caption) <= 500),

  -- Yakalanan balık türleri (çoklu tür desteği)
  fish_species         TEXT[],

  -- Mera bilgisi (spot gizli olsa bile ilçe bilgisi saklanır)
  spot_id              UUID        REFERENCES fishing_spots(id) ON DELETE SET NULL,
  -- Gönderildiği anın mera gizlilik seviyesi snapshot'ı.
  -- Sonradan mera gizliliği değişse bile post görünürlüğü
  -- bu anlık değere göre belirlenir.
  spot_privacy_snapshot TEXT       NOT NULL DEFAULT 'public'
                        CHECK (spot_privacy_snapshot IN ('public','friends','private','vip')),
  -- Maskeleme için ilçe/bölge adı (spot private/vip olsa bile gösterilir)
  spot_district        TEXT,

  -- Denormalize sayaçlar (trigger ile güncellenir)
  likes_count          INTEGER     NOT NULL DEFAULT 0,
  comments_count       INTEGER     NOT NULL DEFAULT 0,

  -- fish_logs'dan migrate edilmiş kayıtlar için geri referans
  migrated_from_log_id UUID        REFERENCES fish_logs(id) ON DELETE SET NULL,

  -- Soft delete (içerik kaldırma; fiziksel silme yapmıyoruz)
  is_deleted           BOOLEAN     NOT NULL DEFAULT FALSE,

  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── İndeksler ────────────────────────────────────────────

CREATE INDEX idx_posts_user_id    ON posts (user_id);
CREATE INDEX idx_posts_created_at ON posts (created_at DESC);
CREATE INDEX idx_posts_spot_id    ON posts (spot_id) WHERE spot_id IS NOT NULL;

-- ─── RLS ──────────────────────────────────────────────────

ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- public meralardaki gönderiler herkese açık
CREATE POLICY "public_posts_visible"
  ON posts FOR SELECT
  USING (
    is_deleted = FALSE
    AND spot_privacy_snapshot = 'public'
  );

-- friends meralardaki gönderiler: sahip veya takipçi görebilir
CREATE POLICY "friends_posts_visible"
  ON posts FOR SELECT
  USING (
    is_deleted = FALSE
    AND spot_privacy_snapshot = 'friends'
    AND (
      user_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM follows
        WHERE follower_id = auth.uid()
          AND following_id = posts.user_id
      )
    )
  );

-- private ve vip gönderiler sadece sahibine görünür
-- (vip mera erişim hakları FAZ 3 UI'ında rütbeye göre genişletilebilir)
CREATE POLICY "private_posts_owner_only"
  ON posts FOR SELECT
  USING (
    is_deleted = FALSE
    AND spot_privacy_snapshot IN ('private','vip')
    AND user_id = auth.uid()
  );

-- Sadece kendi adına post eklenebilir
CREATE POLICY "posts_insert_own"
  ON posts FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Sadece kendi postunu güncelleyebilir
CREATE POLICY "posts_update_own"
  ON posts FOR UPDATE
  TO authenticated
  USING  (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Sadece kendi postunu silebilir (is_deleted=true set etmek de UPDATE ile yapılır)
CREATE POLICY "posts_delete_own"
  ON posts FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());
