import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/data/models/post_model.dart';
import 'package:balikci_app/data/repositories/post_repository.dart';

// ─── Repository ────────────────────────────────────────────────────────────

/// PostRepository singleton provider.
final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository();
});

// ─── Arkadaşlar Akışı ──────────────────────────────────────────────────────

/// Takip edilen kullanıcıların gönderilerini yöneten notifier.
///
/// [loadMore] cursor-based pagination ile sonraki sayfayı yükler.
/// [refresh] listeyi sıfırlayıp baştan çeker.
class FriendsFeedNotifier extends AsyncNotifier<List<PostModel>> {
  late PostRepository _repo;

  /// loadMore çalışırken true; UI'da "daha fazla yükleniyor" göstergesi için.
  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  @override
  Future<List<PostModel>> build() async {
    _repo = ref.watch(postRepositoryProvider);
    try {
      return await _repo.getFriendsFeed();
    } catch (e) {
      debugPrint('FriendsFeedNotifier.build hatası: $e');
      return [];
    }
  }

  /// Mevcut listenin sonundaki cursor ile sonraki sayfayı ekler.
  Future<void> loadMore() async {
    if (_isLoadingMore) return;
    final current = state.valueOrNull;
    if (current == null || current.isEmpty) return;

    _isLoadingMore = true;
    try {
      final cursor = current.last.createdAt;
      final more = await _repo.getFriendsFeed(cursor: cursor);
      state = AsyncData([...current, ...more]);
    } catch (e) {
      debugPrint('FriendsFeedNotifier.loadMore hatası: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Listeyi temizler ve ilk sayfayı yeniden çeker.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getFriendsFeed());
  }
}

final friendsFeedProvider =
    AsyncNotifierProvider<FriendsFeedNotifier, List<PostModel>>(
  FriendsFeedNotifier.new,
);

// ─── Türkiye (Global) Akışı ────────────────────────────────────────────────

/// Tüm public gönderileri yöneten notifier — "Türkiye" sekmesi.
class GlobalFeedNotifier extends AsyncNotifier<List<PostModel>> {
  late PostRepository _repo;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  @override
  Future<List<PostModel>> build() async {
    _repo = ref.watch(postRepositoryProvider);
    try {
      return await _repo.getGlobalFeed();
    } catch (e) {
      debugPrint('GlobalFeedNotifier.build hatası: $e');
      return [];
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore) return;
    final current = state.valueOrNull;
    if (current == null || current.isEmpty) return;

    _isLoadingMore = true;
    try {
      final cursor = current.last.createdAt;
      final more = await _repo.getGlobalFeed(cursor: cursor);
      state = AsyncData([...current, ...more]);
    } catch (e) {
      debugPrint('GlobalFeedNotifier.loadMore hatası: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getGlobalFeed());
  }
}

final globalFeedProvider =
    AsyncNotifierProvider<GlobalFeedNotifier, List<PostModel>>(
  GlobalFeedNotifier.new,
);

// ─── Kullanıcı Gönderileri ─────────────────────────────────────────────────

/// Belirli bir kullanıcının gönderilerini yöneten notifier (family).
///
/// Parametre olarak userId alır; profil ekranındaki post grid'i için kullanılır.
class UserPostsNotifier
    extends FamilyAsyncNotifier<List<PostModel>, String> {
  late PostRepository _repo;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  @override
  Future<List<PostModel>> build(String userId) async {
    _repo = ref.watch(postRepositoryProvider);
    try {
      return await _repo.getPostsByUser(userId);
    } catch (e) {
      debugPrint('UserPostsNotifier.build hatası ($userId): $e');
      return [];
    }
  }

  Future<void> loadMore(String userId) async {
    if (_isLoadingMore) return;
    final current = state.valueOrNull;
    if (current == null || current.isEmpty) return;

    _isLoadingMore = true;
    try {
      final cursor = current.last.createdAt;
      final more = await _repo.getPostsByUser(userId, cursor: cursor);
      state = AsyncData([...current, ...more]);
    } catch (e) {
      debugPrint('UserPostsNotifier.loadMore hatası ($userId): $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> refresh(String userId) async {
    state = const AsyncLoading();
    state =
        await AsyncValue.guard(() => _repo.getPostsByUser(userId));
  }
}

final userPostsProvider = AsyncNotifierProvider.family<UserPostsNotifier,
    List<PostModel>, String>(
  UserPostsNotifier.new,
);

// ─── Beğeni Durumu ─────────────────────────────────────────────────────────

/// Giriş yapmış kullanıcının belirtilen postu beğenip beğenmediği.
/// autoDispose: post detay ekranı kapatılınca cache temizlenir.
final likedPostsProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, postId) async {
  final repo = ref.read(postRepositoryProvider);
  return repo.isLikedByMe(postId);
});

// ─── Yorumlar ──────────────────────────────────────────────────────────────

/// Bir gönderinin yorum listesi.
/// autoDispose: yorum ekranı kapatılınca cache temizlenir.
final postCommentsProvider =
    FutureProvider.autoDispose.family<List<CommentModel>, String>(
  (ref, postId) async {
    final repo = ref.read(postRepositoryProvider);
    return repo.getComments(postId);
  },
);
