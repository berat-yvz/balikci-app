import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:balikci_app/core/constants/app_constants.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/core/utils/geo_utils.dart';
import 'package:balikci_app/data/models/checkin_model.dart';
import 'package:balikci_app/data/repositories/checkin_repository.dart';
import 'package:balikci_app/data/repositories/spot_repository.dart';
import 'package:balikci_app/features/map/widgets/vote_dialog.dart';

/// Kullanıcı konumu yakın aktif check-in'i kontrol eder ve
/// daha önce oylanmadıysa [VoteDialog]'u tetikler.
class ProximityVoteService {
  ProximityVoteService._();
  static final ProximityVoteService instance = ProximityVoteService._();

  final Set<String> _shownCheckinIds = {};
  final CheckinRepository _checkins = CheckinRepository();
  final SpotRepository _spots = SpotRepository();

  Future<void> checkAndShowVoteDialog(BuildContext context) async {
    try {
      final uid = SupabaseService.auth.currentUser?.id;
      if (uid == null) return;

      if (!context.mounted) return;

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );

      if (!context.mounted) return;

      final candidates = await _checkins.getActiveCheckinsNearby();
      if (!context.mounted) return;

      /// null: mera yok; değer: lat/lng
      final spotCoords = <String, (double, double)?>{};

      CheckinModel? closest;
      var bestMeters = double.infinity;

      for (final c in candidates) {
        if (_shownCheckinIds.contains(c.id)) continue;
        if (c.userId == uid) continue;

        late final (double, double)? pair;
        if (spotCoords.containsKey(c.spotId)) {
          pair = spotCoords[c.spotId];
        } else {
          final spot = await _spots.getSpotById(c.spotId);
          if (spot == null) {
            spotCoords[c.spotId] = null;
            pair = null;
          } else {
            pair = (spot.lat, spot.lng);
            spotCoords[c.spotId] = pair;
          }
        }

        if (pair == null) continue;
        final (slat, slng) = pair;

        final m = GeoUtils.distanceInMeters(
          lat1: pos.latitude,
          lng1: pos.longitude,
          lat2: slat,
          lng2: slng,
        );
        if (m <= AppConstants.checkinRadiusMeters && m < bestMeters) {
          bestMeters = m;
          closest = c;
        }
      }

      if (closest == null || !context.mounted) return;

      final existingVote = await _checkins.getUserVote(closest.id, uid);
      if (existingVote != null) return;
      if (!context.mounted) return;

      _shownCheckinIds.add(closest.id);
      await VoteDialog.show(context, checkin: closest);
    } catch (_) {
      // Sessiz: konum / ağ hatalarında kullanıcıya mesaj gösterme
    }
  }
}
