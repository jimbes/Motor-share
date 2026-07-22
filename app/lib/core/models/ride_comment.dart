class RideCommentAuthor {
  const RideCommentAuthor({required this.id, required this.name});

  final int id;
  final String name;

  factory RideCommentAuthor.fromJson(Map<String, dynamic> json) {
    return RideCommentAuthor(id: json['id'] as int, name: json['name'] as String);
  }
}

class RideComment {
  const RideComment({required this.id, required this.body, required this.createdAt, required this.user});

  final int id;
  final String body;
  final DateTime createdAt;
  final RideCommentAuthor user;

  factory RideComment.fromJson(Map<String, dynamic> json) {
    return RideComment(
      id: json['id'] as int,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      user: RideCommentAuthor.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
