import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/knot_model.dart';

/// Düğüm repository — Supabase `knots` tablosu.
class KnotRepository {
  final SupabaseClient _db = SupabaseService.client;

  Future<List<KnotModel>> getKnots({String? typeFilter}) async {
    try {
      var query = _db.from('knots').select();
      if (typeFilter != null && typeFilter.trim().isNotEmpty) {
        query = query.eq('type', typeFilter);
      }

      final response = await query;
      return (response as List)
          .map((row) => KnotModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Düğümler yüklenemedi: ${e.message}');
    } catch (e) {
      throw Exception('Düğümler yüklenemedi: $e');
    }
  }
}
