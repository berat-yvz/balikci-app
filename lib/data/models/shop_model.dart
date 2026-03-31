/// Dükkan modeli — Supabase `shops` tablosu.
class ShopModel {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String type;
  final String? phone;
  final String? hours;
  final String? addedBy;
  final bool verified;

  const ShopModel({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.type,
    this.phone,
    this.hours,
    this.addedBy,
    this.verified = false,
  });

  factory ShopModel.fromJson(Map<String, dynamic> json) => ShopModel(
    id: json['id'] as String,
    name: json['name'] as String,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    type: json['type'] as String,
    phone: json['phone'] as String?,
    hours: json['hours'] as String?,
    addedBy: json['added_by'] as String?,
    verified: json['verified'] as bool? ?? false,
  );
}
