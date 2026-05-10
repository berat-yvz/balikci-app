import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/data/repositories/shadow_point_repository.dart';

final shadowPointSummaryProvider =
    FutureProvider.autoDispose.family<ShadowPointSummary, String>((ref, userId) {
  return ShadowPointRepository().getUserShadowPoints(userId);
});

final recentShadowEventsProvider =
    FutureProvider.autoDispose.family<List<ShadowPointEvent>, String>((ref, userId) {
  return ShadowPointRepository().getRecentShadowEvents(userId);
});
