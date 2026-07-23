import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/ride.dart';
import '../core/models/rider_profile.dart';
import '../core/repositories/ride_repository.dart';
import '../core/repositories/user_repository.dart';
import '../l10n/app_localizations.dart';
import '../theme/redl_colors.dart';
import '../theme/redl_spacing.dart';
import '../theme/redl_text_styles.dart';
import '../widgets/ride_card.dart';
import 'ride_summary_screen.dart';

class RiderProfileScreen extends StatefulWidget {
  const RiderProfileScreen({super.key, required this.username});

  final String username;

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  final _scrollController = ScrollController();
  final List<Ride> _rides = [];
  RiderProfile? _profile;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _profile == null) return;
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
      final profile = await context.read<UserRepository>().show(widget.username);
      if (!mounted) return;
      final feed = await context.read<RideRepository>().feed(page: 1, userId: profile.id);
      if (mounted) {
        setState(() {
          _profile = profile;
          _rides
            ..clear()
            ..addAll(feed.rides);
          _page = 1;
          _hasMore = feed.hasMorePages;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.riderProfileLoadError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final profile = _profile;
    if (profile == null) return;
    setState(() => _loadingMore = true);
    try {
      final feed = await context.read<RideRepository>().feed(page: _page + 1, userId: profile.id);
      setState(() {
        _rides.addAll(feed.rides);
        _page += 1;
        _hasMore = feed.hasMorePages;
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text('@${widget.username}')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: RedlColors.accent))
            : _error != null || _profile == null
                ? Center(child: Text(_error ?? '', style: RedlText.body(color: RedlColors.textSecondary)))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(RedlSpacing.screenPadding, 16, RedlSpacing.screenPadding, 24),
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: RedlColors.surface4,
                              backgroundImage: _profile!.avatarUrl != null ? NetworkImage(_profile!.avatarUrl!) : null,
                              child: _profile!.avatarUrl == null ? const Icon(Icons.person, color: RedlColors.baseAlt, size: 28) : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_profile!.name, style: RedlText.title(fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(l10n.riderSince(_profile!.memberSince.year.toString()), style: RedlText.meta()),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          decoration: const BoxDecoration(
                            border: Border.symmetric(horizontal: BorderSide(color: RedlColors.divider)),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            children: [
                              _ProfileStat(label: l10n.statRides, value: '${_profile!.ridesCount}'),
                              _ProfileStat(label: l10n.statDistance, value: '${_profile!.distanceKm.toStringAsFixed(0)} km'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(l10n.feedRecentActivity, style: RedlText.eyebrow()),
                        const SizedBox(height: 12),
                        if (_rides.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: Text(l10n.feedEmpty, style: RedlText.meta(color: RedlColors.textSecondary))),
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

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: RedlText.statValue(fontSize: 17)),
          const SizedBox(height: 4),
          Text(label, style: RedlText.eyebrow(fontSize: 9)),
        ],
      ),
    );
  }
}
