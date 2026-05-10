-- VIP mera ile etiketlenen gönderiler genel / arkadaş akışında görünsün.
-- Önceden 'vip' snapshot, private ile aynı policy'de olduğu için yalnızca gönderi sahibi
-- görebiliyordu. İstemci tarafında spot adı/konumu maskelenir (PostModel.displaySpotName).

DROP POLICY IF EXISTS "private_posts_owner_only" ON posts;

CREATE POLICY "private_posts_owner_only"
  ON posts FOR SELECT
  USING (
    is_deleted = FALSE
    AND spot_privacy_snapshot = 'private'
    AND user_id = auth.uid()
  );

CREATE POLICY "vip_posts_visible"
  ON posts FOR SELECT
  USING (
    is_deleted = FALSE
    AND spot_privacy_snapshot = 'vip'
  );
