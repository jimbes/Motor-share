import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/ride.dart';
import '../core/models/rider_stats.dart';
import '../core/repositories/ride_repository.dart';
import '../core/route_observer.dart';
import '../state/auth_provider.dart';
import '../theme/redl_colors.dart';
import '../theme/redl_spacing.dart';
import '../theme/redl_text_styles.dart';
import '../widgets/ride_card.dart';
import 'ride_summary_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with RouteAware {
  final _scrollController = ScrollController();
  final List<Ride> _rides = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  RiderStats? _stats;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) appRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // A pushed route (Record -> Ride Summary) was popped and we're visible
    // again - a new ride may have just been saved, so refresh the feed.
    _load();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore) return;
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<RideRepository>();
      final results = await Future.wait([repo.feed(page: 1), repo.myStats()]);
      final page = results[0] as RideFeedPage;
      final stats = results[1] as RiderStats;
      setState(() {
        _rides
          ..clear()
          ..addAll(page.rides);
        _page = 1;
        _hasMore = page.hasMorePages;
        _stats = stats;
      });
    } catch (_) {
      setState(() => _error = 'Could not load the feed.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final page = await context.read<RideRepository>().feed(page: _page + 1);
      setState(() {
        _rides.addAll(page.rides);
        _page += 1;
        _hasMore = page.hasMorePages;
      });
    } catch (_) {
      // Silently keep current state - user can retry by scrolling again.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _toggleLike(Ride ride) async {
    final repo = context.read<RideRepository>();
    final index = _rides.indexWhere((r) => r.id == ride.id);
    if (index == -1) return;

    final optimistic = ride.copyWith(
      likedByMe: !ride.likedByMe,
      likesCount: ride.likesCount + (ride.likedByMe ? -1 : 1),
    );
    setState(() => _rides[index] = optimistic);

    try {
      final result = ride.likedByMe ? await repo.unlike(ride.id) : await repo.like(ride.id);
      if (!mounted) return;
      setState(() {
        _rides[index] = _rides[index].copyWith(likesCount: result.likesCount, likedByMe: result.likedByMe);
      });
    } catch (_) {
      if (mounted) setState(() => _rides[index] = ride);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final stats = _stats;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: RedlColors.accent))
              : _error != null
                  ? _ErrorState(message: _error!, onRetry: _load)
                  : ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        RedlSpacing.screenPadding, RedlSpacing.safeTop, RedlSpacing.screenPadding, 24,
                      ),
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(radius: 16, backgroundColor: RedlColors.surface4),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('Hey, ${user?.name.split(' ').first ?? ''}', style: RedlText.title(fontSize: 14)),
                            ),
                            const CircleAvatar(radius: 16, backgroundColor: RedlColors.surface4, child: Icon(Icons.settings_outlined, size: 16, color: RedlColors.baseAlt)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          decoration: BoxDecoration(color: RedlColors.accent, borderRadius: BorderRadius.circular(RedlRadius.md)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('THIS WEEK', style: RedlText.eyebrow(fontSize: 10, color: RedlColors.accentTint)),
                              const SizedBox(height: 6),
                              Text('${(stats?.weekDistanceKm ?? 0).toStringAsFixed(0)} km', style: RedlText.statValue(fontSize: 30)),
                              const SizedBox(height: 4),
                              Text('${stats?.weekRidesCount ?? 0} rides', style: RedlText.body(fontSize: 11, color: RedlColors.accentTint)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text('RECENT ACTIVITY', style: RedlText.eyebrow()),
                        const SizedBox(height: 12),
                        if (_rides.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text('No rides yet. Go record one!', style: RedlText.meta(color: RedlColors.textSecondary)),
                            ),
                          )
                        else
                          ..._rides.map((ride) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: RideCard(
                                  ride: ride,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => RideSummaryScreen.view(rideId: ride.id)),
                                  ),
                                  onToggleLike: () => _toggleLike(ride),
                                ),
                              )),
                        if (_loadingMore)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator(color: RedlColors.accent)),
                          ),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: RedlText.body(color: RedlColors.textSecondary)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
