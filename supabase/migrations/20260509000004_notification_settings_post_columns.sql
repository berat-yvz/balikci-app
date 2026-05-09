-- ============================================================
-- FAZ 2 — notification_settings tablosuna sosyal akış sütunları
-- post_like ve post_comment bildirim tercihleri
-- ============================================================

ALTER TABLE notification_settings
  ADD COLUMN IF NOT EXISTS post_like    BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS post_comment BOOLEAN NOT NULL DEFAULT TRUE;
