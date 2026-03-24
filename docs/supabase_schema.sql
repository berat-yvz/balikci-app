-- ============================================================
-- Balıkçı Super App — Supabase Veritabanı Kurulum Scripti
-- ARCHITECTURE.md → Veritabanı Şeması bölümünden alındı.
-- Supabase SQL Editor'a yapıştırıp çalıştır.
-- ============================================================


-- ─── TABLOLAR ─────────────────────────────────────────────


CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  username TEXT UNIQUE NOT NULL,
  avatar_url TEXT,
  rank TEXT DEFAULT 'acemi' CHECK (rank IN ('acemi','olta_kurdu','usta','deniz_reisi')),
  total_score INTEGER DEFAULT 0,
  sustainability_score INTEGER DEFAULT 0,
  fcm_token TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);


CREATE TABLE fishing_spots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  type TEXT CHECK (type IN ('kıyı','kayalık','iskele','tekne','göl','nehir')),
  privacy_level TEXT DEFAULT 'public' CHECK (privacy_level IN ('public','friends','private','vip')),
  description TEXT,
  verified BOOLEAN DEFAULT FALSE,
  muhtar_id UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);


CREATE TABLE shops (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  type TEXT CHECK (type IN ('av_bayi','balik_marketi','tekne_kiralama')),
  phone TEXT,
  hours TEXT,
  added_by UUID REFERENCES users(id),
  verified BOOLEAN DEFAULT FALSE
);


CREATE TABLE checkins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  spot_id UUID REFERENCES fishing_spots(id) ON DELETE CASCADE,
  crowd_level TEXT CHECK (crowd_level IN ('yoğun','normal','az','boş')),
  fish_density TEXT CHECK (fish_density IN ('yoğun','normal','az','yok')),
  photo_url TEXT,
  exif_verified BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);


CREATE TABLE checkin_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  checkin_id UUID REFERENCES checkins(id) ON DELETE CASCADE,
  voter_id UUID REFERENCES users(id) ON DELETE CASCADE,
  vote BOOLEAN NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(checkin_id, voter_id)
);


CREATE TABLE fish_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  spot_id UUID REFERENCES fishing_spots(id),
  species TEXT NOT NULL,
  weight DOUBLE PRECISION,
  length DOUBLE PRECISION,
  photo_url TEXT,
  weather_snapshot JSONB,
  is_private BOOLEAN DEFAULT FALSE,
  released BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);


CREATE TABLE shadow_points (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  giver_id UUID REFERENCES users(id),
  receiver_id UUID REFERENCES users(id),
  source_type TEXT CHECK (source_type IN ('checkin','fish_log')),
  source_id UUID,
  points INTEGER DEFAULT 20,
  created_at TIMESTAMPTZ DEFAULT NOW()
);


CREATE TABLE weather_cache (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  region_key TEXT UNIQUE NOT NULL,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  data_json JSONB NOT NULL,
  fishing_summary TEXT,
  fetched_at TIMESTAMPTZ DEFAULT NOW()
);


CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data_json JSONB,
  read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);


CREATE TABLE follows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id UUID REFERENCES users(id) ON DELETE CASCADE,
  following_id UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(follower_id, following_id)
);


-- ─── ROW LEVEL SECURITY (RLS) ─────────────────────────────


-- fishing_spots
ALTER TABLE fishing_spots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public spots visible to all"
  ON fishing_spots FOR SELECT
  USING (privacy_level = 'public');

CREATE POLICY "Friends spots visible to followers"
  ON fishing_spots FOR SELECT
  USING (
    privacy_level = 'friends'
    AND user_id IN (SELECT following_id FROM follows WHERE follower_id = auth.uid())
  );

CREATE POLICY "Private spots only for owner"
  ON fishing_spots FOR SELECT
  USING (privacy_level = 'private' AND user_id = auth.uid());

CREATE POLICY "VIP spots for usta and above"
  ON fishing_spots FOR SELECT
  USING (
    privacy_level = 'vip'
    AND (SELECT rank FROM users WHERE id = auth.uid()) IN ('usta', 'deniz_reisi')
  );

CREATE POLICY "Authenticated insert own fishing_spots"
  ON fishing_spots FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Authenticated update own fishing_spots"
  ON fishing_spots FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Authenticated delete own fishing_spots"
  ON fishing_spots FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- fish_logs
ALTER TABLE fish_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public logs visible to all"
  ON fish_logs FOR SELECT
  USING (is_private = FALSE);

CREATE POLICY "Private logs only for owner"
  ON fish_logs FOR SELECT
  USING (is_private = TRUE AND user_id = auth.uid());

-- checkin_votes
ALTER TABLE checkin_votes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can vote once per checkin"
  ON checkin_votes FOR INSERT
  WITH CHECK (voter_id = auth.uid());

-- follows
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can follow others"
  ON follows FOR INSERT
  WITH CHECK (follower_id = auth.uid());

CREATE POLICY "Users can unfollow"
  ON follows FOR DELETE
  USING (follower_id = auth.uid());

CREATE POLICY "Follows visible to all"
  ON follows FOR SELECT
  USING (true);
