-- Kullanıcı kendi satırlarında read güncelleyebilsin (markAsRead + markAllAsRead).
-- SELECT politikası docs’ta vardı; UPDATE yoksa toplu okundu isteği RLS’de sessizce 0 satır etkiler.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'notifications'
      AND policyname = 'Users update own notifications'
  ) THEN
    CREATE POLICY "Users update own notifications"
      ON notifications FOR UPDATE
      TO authenticated
      USING (user_id = auth.uid())
      WITH CHECK (user_id = auth.uid());
  END IF;
END $$;
