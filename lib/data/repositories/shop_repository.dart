import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/shop_model.dart';

/// Dükkan repository — Supabase `shops` tablosu.
class ShopRepository {
  final SupabaseClient _db = SupabaseService.client;

  Future<List<ShopModel>> getShops() async {
    try {
      final response = await _db.from('shops').select();
      return (response as List)
          .map((row) => ShopModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Dükkanlar yüklenemedi: ${e.message}');
    } catch (e) {
      throw Exception('Dükkanlar yüklenemedi: $e');
    }
  }
}
