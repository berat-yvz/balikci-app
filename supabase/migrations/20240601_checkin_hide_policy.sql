-- H6: %70 yanlış oy → check-in gizleme
-- Client-side evaluateAndHide() metodunun is_active = false yapabilmesi için
-- check-in sahibine UPDATE izni ver (score-calculator Edge Function gelene kadar).

CREATE POLICY "Owner can deactivate own checkin"
  ON checkins FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- NOT: score-calculator Edge Function devreye girince bu policy
-- service_role bazlı olarak güncellenecek (H8 kapsamı).
