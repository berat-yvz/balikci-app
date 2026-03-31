import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/notification_model.dart';
import 'package:balikci_app/data/repositories/notification_repository.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';

/// NotificationRepository singleton provider.
final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

/// Giriş yapmış kullanıcının bildirimlerini gerçek zamanlı döner.
final myNotificationsProvider =
    StreamProvider<List<NotificationModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream<List<NotificationModel>>.empty();
  }

  // Riverpod StreamProvider içinden repo çağırmak yerine Realtime stream
  // kaynağını Supabase'den alıyoruz.
  final stream = SupabaseService.client
      .from('notifications')
      .stream(primaryKey: const ['id']).eq('user_id', user.id);

  return stream.map((rows) {
    final list = (rows as List)
        .map(
          (row) => NotificationModel.fromJson(
            row as Map<String, dynamic>,
          ),
        )
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });
});

/// Okunmamış bildirim sayısı.
final unreadCountProvider = FutureProvider<int>((ref) async {
  // Stream değişince bu FutureProvider da tekrar hesaplansın.
  ref.watch(myNotificationsProvider);

  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getUnreadCount();
});

