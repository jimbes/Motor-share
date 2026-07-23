/// A lightweight rider reference - used for ride/comment authors and
/// people-search results.
class UserSummary {
  const UserSummary({required this.id, required this.name, this.username, this.avatarUrl});

  final int id;
  final String name;
  final String? username;
  final String? avatarUrl;

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      id: json['id'] as int,
      name: json['name'] as String,
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
