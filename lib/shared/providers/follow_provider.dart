import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/data/repositories/follow_repository.dart';

/// FollowRepository singleton provider.
final followRepositoryProvider = Provider<FollowRepository>((ref) {
  return FollowRepository();
});
