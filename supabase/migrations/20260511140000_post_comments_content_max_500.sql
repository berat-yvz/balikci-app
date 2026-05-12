-- post_comments.content üst sınırını 500 karaktere çıkarır (önceki şema 300).
-- Tablo zaten 20260509000002 / 20260509120000 ile oluşturuldu; posts FK korunur.

ALTER TABLE post_comments DROP CONSTRAINT IF EXISTS post_comments_content_check;

ALTER TABLE post_comments
  ADD CONSTRAINT post_comments_content_check
  CHECK (char_length(content) >= 1 AND char_length(content) <= 500);
