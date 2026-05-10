import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/friend_request_model.dart';
import 'package:balikci_app/data/models/user_model.dart';
import 'package:balikci_app/data/repositories/friend_request_repository.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/follow_provider.dart';
import 'package:balikci_app/shared/providers/user_provider.dart';

final friendRequestRepositoryProvider = Provider<FriendRequestRepository>((
  ref,
) {
  return FriendRequestRepository();
});

/// Soğuk açılışta `authState` ilk olayı gelmeden `currentUser` boş kalabiliyor; bu yüzden
/// arkadaş listesi yanlışlıkla boş dönmesin diye auth akışının ilk snapshot'ını bekler.
Future<String?> _resolvedCurrentUserId(Ref ref) async {
  ref.watch(currentUserProvider);
  ref.watch(authStateProvider);
  try {
    await ref.read(authStateProvider.future);
  } catch (_) {
    // Oturum yok veya hata — aşağıdaki sync okumaya düş
  }
  final id = ref.read(currentUserProvider)?.id;
  if (id != null && id.isNotEmpty) return id;
  return SupabaseService.auth.currentUser?.id;
}

/// Başka bir kullanıcıyla arkadaşlık / istek durumu.
enum SocialEdgeKind {
  self,
  mutualFriend,
  outgoingPending,
  incomingPending,
  stranger,
}

class SocialEdge {
  final SocialEdgeKind kind;
  final String? incomingRequestId;

  const SocialEdge(this.kind, [this.incomingRequestId]);
}

final socialEdgeProvider =
    FutureProvider.family<SocialEdge, String>((ref, otherUserId) async {
      ref.watch(authStateProvider);
      final me = await _resolvedCurrentUserId(ref);
      if (me == null || me.isEmpty) return const SocialEdge(SocialEdgeKind.stranger);
      if (me == otherUserId) return const SocialEdge(SocialEdgeKind.self);

      final followRepo = ref.read(followRepositoryProvider);
      final frRepo = ref.read(friendRequestRepositoryProvider);

      if (await followRepo.areMutualFriends(otherUserId)) {
        return const SocialEdge(SocialEdgeKind.mutualFriend);
      }
      if (await frRepo.hasPendingOutgoing(otherUserId)) {
        return const SocialEdge(SocialEdgeKind.outgoingPending);
      }
      if (await frRepo.hasPendingIncomingFrom(otherUserId)) {
        final id = await frRepo.getIncomingRequestId(otherUserId);
        return SocialEdge(SocialEdgeKind.incomingPending, id);
      }
      return const SocialEdge(SocialEdgeKind.stranger);
    });

/// Karşılıklı takip (kabul edilmiş arkadaşlıklar) — oturumdaki kullanıcı.
///
/// autoDispose değil: [FriendsHubScreen] sekmesi değişince istek yarım kalmasın / boş state
/// flicker olmasın; yenileme [ref.invalidate(mutualFriendsProvider)] ile.
final mutualFriendsProvider = FutureProvider<List<UserModel>>((ref) async {
  ref.watch(authStateProvider);
  final me = await _resolvedCurrentUserId(ref);
  if (me == null || me.isEmpty) return [];
  final followRepo = ref.read(followRepositoryProvider);
  final userRepo = ref.read(userRepositoryProvider);
  final ids = await followRepo.getMutualFriendIds(me);
  if (ids.isEmpty) return [];
  return userRepo.getProfilesByIds(ids);
});

/// [userId] için arkadaş (karşılıklı takip) profilleri.
final mutualFriendsForUserProvider =
    FutureProvider.autoDispose.family<List<UserModel>, String>((
      ref,
      userId,
    ) async {
      final followRepo = ref.read(followRepositoryProvider);
      final userRepo = ref.read(userRepositoryProvider);
      final ids = await followRepo.getMutualFriendIds(userId);
      if (ids.isEmpty) return [];
      return userRepo.getProfilesByIds(ids);
    });

/// Profil kartı için arkadaş sayısı.
final mutualFriendCountForUserProvider =
    FutureProvider.family<int, String>((ref, userId) async {
      final ids =
          await ref.read(followRepositoryProvider).getMutualFriendIds(userId);
      return ids.length;
    });

final incomingFriendRequestsProvider =
    FutureProvider.autoDispose<List<FriendRequestModel>>((ref) async {
      return ref.read(friendRequestRepositoryProvider).listIncomingPending();
    });

/// Gelen istek + gönderen profili.
final incomingRequestsWithProfilesProvider = FutureProvider.autoDispose<
    List<({FriendRequestModel req, UserModel? user})>>((ref) async {
  final fr = ref.read(friendRequestRepositoryProvider);
  final usersRepo = ref.read(userRepositoryProvider);
  final list = await fr.listIncomingPending();
  if (list.isEmpty) return [];
  final ids = list.map((e) => e.fromUserId).toList();
  final profiles = await usersRepo.getProfilesByIds(ids);
  final byId = {for (final u in profiles) u.id: u};
  return [
    for (final r in list) (req: r, user: byId[r.fromUserId]),
  ];
});
