-- ============================================================
-- FAZ 1 — Sosyal Akış Veritabanı
-- posts, post_likes, post_comments tabloları
-- Denormalize sayaç trigger'ları + RLS politikaları
-- ============================================================

-- ─── TABLO: posts ─────────────────────────────────────────

CREATE TABLE posts (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- İçerik
  caption         TEXT,
  photo_url       TEXT,

  -- Balık bilgisi (isteğe bağlı)
  fish_species    TEXT,
  fish_weight     DOUBLE PRECISION,
  fish_length     DOUBLE PRECISION,
  fish_released   BOOLEAN     NOT NULL DEFAULT FALSE,

  -- Mera bilgisi
  -- spot_id gizli/vip olsa bile kaydedilir; UI katmanı maskelemeden sorumlu (FAZ 3)
  spot_id         UUID        REFERENCES fishing_spots(id) ON DELETE SET NULL,
  spot_lat        DOUBLE PRECISION,   -- yaklaşık koordinat, mera gizli bile yayınlanabilir
  spot_lng        DOUBLE PRECISION,

  -- Hava snapshot (kayıt anındaki anlık veri)
  weather_snapshot JSONB,

  -- Gizlilik matrisi (fishing_spots.privacy_level ile aynı semantik)
  -- public   → herkes görür
  -- friends  → takip edenler görür
  -- private  → sadece sahip görür
  -- vip      → usta / deniz_reisi rütbesi gerekir
  visibility      TEXT        NOT NULL DEFAULT 'public'
                  CHECK (visibility IN ('public','friends','private','vip')),

  -- Post tipi
  post_type       TEXT        NOT NULL DEFAULT 'catch'
                  CHECK (post_type IN ('catch','checkin','spot','general')),

  -- Denormalize sayaçlar (trigger ile güncellenir — JOIN'siz hızlı okuma)
  likes_count     INTEGER     NOT NULL DEFAULT 0,
  comments_count  INTEGER     NOT NULL DEFAULT 0,

  -- fish_logs'dan migrate edilen kayıtlar için geriye dönük bağlantı
  legacy_fish_log_id UUID,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Sık kullanılan sorgular için indeksler
CREATE INDEX idx_posts_user_id      ON posts (user_id);
CREATE INDEX idx_posts_created_at   ON posts (created_at DESC);
CREATE INDEX idx_posts_visibility   ON posts (visibility);
CREATE INDEX idx_posts_spot_id      ON posts (spot_id) WHERE spot_id IS NOT NULL;

-- updated_at otomatik güncelleme trigger'ı
CREATE OR REPLACE FUNCTION set_post_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_posts_updated_at
  BEFORE UPDATE ON posts
  FOR EACH ROW EXECUTE FUNCTION set_post_updated_at();


-- ─── TABLO: post_likes ────────────────────────────────────

CREATE TABLE post_likes (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id    UUID        NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (post_id, user_id)
);

CREATE INDEX idx_post_likes_post_id ON post_likes (post_id);
CREATE INDEX idx_post_likes_user_id ON post_likes (user_id);

-- Beğeni eklenince likes_count artır
CREATE OR REPLACE FUNCTION fn_increment_likes_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE posts
  SET likes_count = likes_count + 1
  WHERE id = NEW.post_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_post_likes_insert
  AFTER INSERT ON post_likes
  FOR EACH ROW EXECUTE FUNCTION fn_increment_likes_count();

-- Beğeni kaldırılınca likes_count azalt (minimum 0)
CREATE OR REPLACE FUNCTION fn_decrement_likes_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE posts
  SET likes_count = GREATEST(0, likes_count - 1)
  WHERE id = OLD.post_id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_post_likes_delete
  AFTER DELETE ON post_likes
  FOR EACH ROW EXECUTE FUNCTION fn_decrement_likes_count();


-- ─── TABLO: post_comments ─────────────────────────────────

CREATE TABLE post_comments (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id           UUID        NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id           UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  parent_comment_id UUID        REFERENCES post_comments(id) ON DELETE CASCADE, -- iç içe yorum desteği
  body              TEXT        NOT NULL CHECK (char_length(body) BETWEEN 1 AND 500),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_post_comments_post_id    ON post_comments (post_id);
CREATE INDEX idx_post_comments_user_id    ON post_comments (user_id);
CREATE INDEX idx_post_comments_parent_id  ON post_comments (parent_comment_id)
  WHERE parent_comment_id IS NOT NULL;

-- updated_at güncelleme
CREATE OR REPLACE FUNCTION set_comment_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_comments_updated_at
  BEFORE UPDATE ON post_comments
  FOR EACH ROW EXECUTE FUNCTION set_comment_updated_at();

-- Yorum eklenince comments_count artır
CREATE OR REPLACE FUNCTION fn_increment_comments_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE posts
  SET comments_count = comments_count + 1
  WHERE id = NEW.post_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_post_comments_insert
  AFTER INSERT ON post_comments
  FOR EACH ROW EXECUTE FUNCTION fn_increment_comments_count();

-- Yorum silinince comments_count azalt (minimum 0)
CREATE OR REPLACE FUNCTION fn_decrement_comments_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE posts
  SET comments_count = GREATEST(0, comments_count - 1)
  WHERE id = OLD.post_id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_post_comments_delete
  AFTER DELETE ON post_comments
  FOR EACH ROW EXECUTE FUNCTION fn_decrement_comments_count();


-- ─── ROW LEVEL SECURITY: posts ────────────────────────────

ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- public → herkes okuyabilir
CREATE POLICY "posts_select_public"
  ON posts FOR SELECT
  USING (visibility = 'public');

-- friends → takipçiler okuyabilir
CREATE POLICY "posts_select_friends"
  ON posts FOR SELECT
  USING (
    visibility = 'friends'
    AND (
      user_id = auth.uid()
      OR user_id IN (
        SELECT following_id FROM follows WHERE follower_id = auth.uid()
      )
    )
  );

-- private → yalnızca sahip okuyabilir
CREATE POLICY "posts_select_private"
  ON posts FOR SELECT
  USING (visibility = 'private' AND user_id = auth.uid());

-- vip → usta ve deniz_reisi rütbesi gerekir
CREATE POLICY "posts_select_vip"
  ON posts FOR SELECT
  USING (
    visibility = 'vip'
    AND (
      user_id = auth.uid()
      OR (SELECT rank FROM users WHERE id = auth.uid()) IN ('usta','deniz_reisi')
    )
  );

-- Kayıt sahibi kendi gönderisini ekleyebilir
CREATE POLICY "posts_insert_own"
  ON posts FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Kayıt sahibi kendi gönderisini güncelleyebilir
CREATE POLICY "posts_update_own"
  ON posts FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Kayıt sahibi kendi gönderisini silebilir
CREATE POLICY "posts_delete_own"
  ON posts FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);


-- ─── ROW LEVEL SECURITY: post_likes ──────────────────────

ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;

-- Görünür (public) post'ların beğenileri herkese açık
CREATE POLICY "post_likes_select_all"
  ON post_likes FOR SELECT
  USING (true);

-- Sadece kendi adına beğeni eklenilebilir
CREATE POLICY "post_likes_insert_own"
  ON post_likes FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Sadece kendi beğenisi kaldırılabilir
CREATE POLICY "post_likes_delete_own"
  ON post_likes FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);


-- ─── ROW LEVEL SECURITY: post_comments ───────────────────

ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;

-- Herkes okuyabilir (post zaten görünürse yorumlar da görünür)
CREATE POLICY "post_comments_select_all"
  ON post_comments FOR SELECT
  USING (true);

-- Sadece kendi adına yorum eklenebilir
CREATE POLICY "post_comments_insert_own"
  ON post_comments FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Kendi yorumunu güncelleyebilir
CREATE POLICY "post_comments_update_own"
  ON post_comments FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Kendi yorumunu silebilir
CREATE POLICY "post_comments_delete_own"
  ON post_comments FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);


-- ─── shadow_points: post desteği ──────────────────────────
-- Mevcut source_type kısıtlamasına 'post' ekleniyor

ALTER TABLE shadow_points
  DROP CONSTRAINT IF EXISTS shadow_points_source_type_check;

ALTER TABLE shadow_points
  ADD CONSTRAINT shadow_points_source_type_check
  CHECK (source_type IN ('checkin','fish_log','post'));
