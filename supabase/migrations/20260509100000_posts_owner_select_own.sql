-- Gönderi sahibinin kendi posts satırını (soft delete sonrası dahil) görebilmesi.
-- PostgREST UPDATE ... RETURNING / istemci .select() ile doğrulama RLS SELECT'e tabidir;
-- silinmiş satırlar mevcut "public/friends/private" SELECT politikalarında is_deleted=false
-- şartı yüzünden görünmezdi — güncelleme başarılı olsa bile istemci boş yanıt alırdı.

CREATE POLICY "posts_select_owner_always"
  ON posts FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());
