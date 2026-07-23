import 'user_summary.dart';

class RideComment {
  const RideComment({required this.id, required this.body, required this.createdAt, required this.user});

  final int id;
  final String body;
  final DateTime createdAt;
  final UserSummary user;

  factory RideComment.fromJson(Map<String, dynamic> json) {
    return RideComment(
      id: json['id'] as int,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
