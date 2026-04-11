/// Gelen arkadaşlık isteği satırı (`friend_requests`).
class FriendRequestModel {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String status;
  final DateTime createdAt;

  const FriendRequestModel({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    required this.createdAt,
  });

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) =>
      FriendRequestModel(
        id: json['id'] as String,
        fromUserId: json['from_user_id'] as String,
        toUserId: json['to_user_id'] as String,
        status: json['status'] as String? ?? 'pending',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
