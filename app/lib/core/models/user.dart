class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    this.username,
    required this.email,
    this.avatarUrl,
    this.createdAt,
  });

  final int id;
  final String name;
  final String? username;
  final String email;
  final String? avatarUrl;
  final DateTime? createdAt;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      name: json['name'] as String,
      username: json['username'] as String?,
      email: json['email'] as String,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }
}
