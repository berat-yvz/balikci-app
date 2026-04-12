-- Okundu kabul edilen bildirimlerin kullanıcı tarafından silinmesi (panelden kaldırma).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'notifications'
      AND policyname = 'Users delete own notifications'
  ) THEN
    CREATE POLICY "Users delete own notifications"
      ON notifications FOR DELETE
      TO authenticated
      USING (user_id = auth.uid());
  END IF;
END $$;
