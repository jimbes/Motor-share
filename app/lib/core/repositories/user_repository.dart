import '../api_client.dart';
import '../models/rider_profile.dart';
import '../models/user_summary.dart';

class UserRepository {
  UserRepository(this._client);

  final ApiClient _client;

  Future<List<UserSummary>> search(String query) async {
    final response = await _client.dio.get('/users/search', queryParameters: {'q': query});
    return (response.data as List<dynamic>).map((e) => UserSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<RiderProfile> show(String username) async {
    final response = await _client.dio.get('/users/$username');
    return RiderProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<({bool isFollowing, int followersCount})> follow(String username) async {
    final response = await _client.dio.post('/users/$username/follow');
    return (isFollowing: response.data['is_following'] as bool, followersCount: response.data['followers_count'] as int);
  }

  Future<({bool isFollowing, int followersCount})> unfollow(String username) async {
    final response = await _client.dio.delete('/users/$username/follow');
    return (isFollowing: response.data['is_following'] as bool, followersCount: response.data['followers_count'] as int);
  }
}
