/// Push ve in-app bildirimlerde hedef profil rotası (takip / arkadaşlık).
String? profileUserIdFromNotificationData(Map<String, dynamic> data) {
  for (final key in ['follower_id', 'from_user_id']) {
    final v = data[key];
    if (v is String && v.isNotEmpty) return v;
  }
  return null;
}

/// [type] içinde "follow" geçiyorsa (ör. follow, follow_request, rank değil) karşı profil açılabilir.
bool notificationTypeOpensFollowProfile(String? type) {
  if (type == null || type.isEmpty) return false;
  final t = type.toLowerCase();
  return t.contains('follow');
}
