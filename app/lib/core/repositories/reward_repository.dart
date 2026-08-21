import '../api_client.dart';
import '../models/badge_info.dart';
import '../models/reward_summary.dart';

class RewardRepository {
  RewardRepository(this._client);

  final ApiClient _client;

  Future<RewardSummary> mine() async {
    final response = await _client.dio.get('/me/rewards');
    return RewardSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<BadgeInfo>> catalog() async {
    final response = await _client.dio.get('/rewards');
    final data = response.data as Map<String, dynamic>;
    return (data['badges'] as List<dynamic>)
        .map((e) => BadgeInfo.fromCatalogJson(e as Map<String, dynamic>))
        .toList();
  }
}
