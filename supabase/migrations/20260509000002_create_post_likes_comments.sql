-- ============================================================
-- FAZ 1 — Sosyal Akış: post_likes + post_comments tabloları
-- Beğeni / yorum sayaç trigger'ları
-- Çalıştırma sırası: 2/3  (20260509000001 önce çalışmalı)
-- ============================================================

-- ─── TABLO: post_likes ────────────────────────────────────

CREATE TABLE post_likes (
  post_id    UUID        NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (post_id, user_id)
);

-- ─── TABLO: post_comments ─────────────────────────────────

CREATE TABLE post_comments (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id    UUID        NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content    TEXT        NOT NULL CHECK (char_length(content) BETWEEN 1 AND 300),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_comments_post_id ON post_comments (post_id);

-- ─── TRIGGER: likes_count ─────────────────────────────────

CREATE OR REPLACE FUNCTION update_post_likes_count()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    UPDATE posts
    SET likes_count = likes_count + 1
    WHERE id = NEW.post_id;
    RETURN NEW;
  ELSIF (TG_OP = 'DELETE') THEN
    UPDATE posts
    SET likes_count = GREATEST(0, likes_count - 1)
    WHERE id = OLD.post_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_post_likes_count_insert
  AFTER INSERT ON post_likes
  FOR EACH ROW EXECUTE FUNCTION update_post_likes_count();

CREATE TRIGGER trg_post_likes_count_delete
  AFTER DELETE ON post_likes
  FOR EACH ROW EXECUTE FUNCTION update_post_likes_count();

-- ─── TRIGGER: comments_count ──────────────────────────────

CREATE OR REPLACE FUNCTION update_post_comments_count()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    UPDATE posts
    SET comments_count = comments_count + 1
    WHERE id = NEW.post_id;
    RETURN NEW;
  ELSIF (TG_OP = 'DELETE') THEN
    UPDATE posts
    SET comments_count = GREATEST(0, comments_count - 1)
    WHERE id = OLD.post_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_post_comments_count_insert
  AFTER INSERT ON post_comments
  FOR EACH ROW EXECUTE FUNCTION update_post_comments_count();

CREATE TRIGGER trg_post_comments_count_delete
  AFTER DELETE ON post_comments
  FOR EACH ROW EXECUTE FUNCTION update_post_comments_count();

-- ─── RLS: post_likes ──────────────────────────────────────

ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;

-- Beğeniler herkese açık (hangi post'un kaç beğenisi olduğu zaten posts.likes_count'ta)
CREATE POLICY "post_likes_select_all"
  ON post_likes FOR SELECT
  USING (true);

-- Sadece kendi adına beğeni eklenebilir
CREATE POLICY "post_likes_insert_own"
  ON post_likes FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Sadece kendi beğenisi kaldırılabilir
CREATE POLICY "post_likes_delete_own"
  ON post_likes FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- ─── RLS: post_comments ───────────────────────────────────

ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;

-- Tüm yorumlar okunabilir
CREATE POLICY "post_comments_select_all"
  ON post_comments FOR SELECT
  USING (true);

-- Sadece kendi adına yorum eklenebilir
CREATE POLICY "post_comments_insert_own"
  ON post_comments FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Sadece kendi yorumu silinebilir
CREATE POLICY "post_comments_delete_own"
  ON post_comments FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());
