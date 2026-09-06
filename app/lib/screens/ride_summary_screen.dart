import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../core/models/bike.dart';
import '../core/models/captured_photo.dart';
import '../core/models/reward_summary.dart';
import '../core/models/ride.dart';
import '../core/models/ride_comment.dart';
import '../core/models/ride_sensor_stats.dart';
import '../core/models/speeding_event.dart';
import '../core/models/track_point.dart';
import '../core/models/user_summary.dart';
import '../core/repositories/bike_repository.dart';
import '../core/repositories/ride_repository.dart';
import '../core/ride_draft_store.dart';
import '../core/speed_color.dart';
import '../l10n/app_localizations.dart';
import '../state/auth_provider.dart';
import '../theme/redl_colors.dart';
import '../theme/redl_spacing.dart';
import '../theme/redl_text_styles.dart';
import '../widgets/redl_buttons.dart';
import '../widgets/rider_picker_sheet.dart';
import '../widgets/route_preview_map.dart';
import 'detailed_stats_screen.dart';

enum _Mode { save, view }

class RideSummaryScreen extends StatefulWidget {
  const RideSummaryScreen.save({
    super.key,
    required this.rideId,
    required this.startedAt,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.track,
    this.initialPhotos = const [],
    this.sensorStats,
    this.initialTitle,
    this.initialDescription,
    this.initialBikeId,
    this.recoveredCompanionUsernames = const [],
    this.autoSave = false,
  }) : _mode = _Mode.save,
       justFinishedRewards = null;

  const RideSummaryScreen.view({
    super.key,
    required this.rideId,
    this.justFinishedRewards,
  }) : _mode = _Mode.view,
       startedAt = null,
       durationSeconds = null,
       distanceMeters = null,
       avgSpeedKmh = null,
       maxSpeedKmh = null,
       track = null,
       initialPhotos = const [],
       sensorStats = null,
       initialTitle = null,
       initialDescription = null,
       initialBikeId = null,
       recoveredCompanionUsernames = const [],
       autoSave = false;

  final _Mode _mode;
  final int rideId;
  final RideRewardOutcome? justFinishedRewards;
  final DateTime? startedAt;
  final int? durationSeconds;
  final int? distanceMeters;
  final double? avgSpeedKmh;
  final double? maxSpeedKmh;
  final List<TrackPoint>? track;
  final List<CapturedPhoto> initialPhotos;
  final RideSensorStats? sensorStats;

  /// Prefilled when reopening a save that failed to finish before an app
  /// restart, so the rider's title/description/bike aren't lost along with
  /// the retry (backlog BUG-2).
  final String? initialTitle;
  final String? initialDescription;
  final int? initialBikeId;

  /// Companions tagged on a previous (interrupted) save attempt - reapplied
  /// once the retry succeeds, even though they aren't shown as chips.
  final List<String> recoveredCompanionUsernames;

  /// True when reopened for a recovered pending finish - triggers an
  /// immediate save attempt instead of waiting for the rider to tap Save.
  final bool autoSave;

  @override
  State<RideSummaryScreen> createState() => _RideSummaryScreenState();
}

class _RideSummaryScreenState extends State<RideSummaryScreen> {
  // Save mode.
  final _titleController = TextEditingController();
  bool _defaultTitleSet = false;
  final _descriptionController = TextEditingController();
  List<Bike> _bikes = [];
  Bike? _selectedBike;
  late final List<CapturedPhoto> _selectedPhotos = List.of(
    widget.initialPhotos,
  );
  final List<UserSummary> _selectedCompanions = [];
  bool _saving = false;
  String? _saveError;
  bool _finishConfirmed = false;
  final _draftStore = RideDraftStore();
  Timer? _retryTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  // View mode.
  Ride? _ride;
  bool _loadingRide = true;
  String? _loadError;
  final _commentController = TextEditingController();
  bool _postingComment = false;

  bool get _isSaveMode => widget._mode == _Mode.save;

  @override
  void initState() {
    super.initState();
    if (_isSaveMode) {
      if (widget.initialTitle != null) {
        _titleController.text = widget.initialTitle!;
        _defaultTitleSet = true;
      }
      if (widget.initialDescription != null) {
        _descriptionController.text = widget.initialDescription!;
      }
      _loadBikes();
      _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
        if (!mounted || _saving || _saveError == null) return;
        if (!results.contains(ConnectivityResult.none)) _save();
      });
      if (widget.autoSave) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _save());
      }
    } else {
      _loadRide();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_defaultTitleSet && _isSaveMode) {
      _titleController.text = AppLocalizations.of(context)!.defaultRideTitle;
      _defaultTitleSet = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _commentController.dispose();
    _retryTimer?.cancel();
    _connectivitySub?.cancel();
    if (_isSaveMode && !_saving && !_finishConfirmed) {
      // The rider backed out of this save without it ever completing -
      // treat it the same as the pre-existing "leave without saving"
      // behavior and drop the local safety copy with it.
      unawaited(_draftStore.clearPendingFinish());
    }
    super.dispose();
  }

  Future<void> _loadBikes() async {
    try {
      final bikes = await context.read<BikeRepository>().list();
      if (mounted) {
        setState(() {
          _bikes = bikes;
          if (widget.initialBikeId != null) {
            final match = bikes.where((b) => b.id == widget.initialBikeId);
            _selectedBike = match.isEmpty ? null : match.first;
          } else {
            final defaultBikes = bikes.where((b) => b.isDefault);
            _selectedBike = defaultBikes.isEmpty ? null : defaultBikes.first;
          }
        });
      }
    } catch (_) {
      // Non-fatal - the rider can still save without picking a bike.
    }
  }

  Future<void> _loadRide() async {
    setState(() {
      _loadingRide = true;
      _loadError = null;
    });
    try {
      final ride = await context.read<RideRepository>().show(widget.rideId);
      if (mounted) setState(() => _ride = ride);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final isPrivate = e is DioException && e.response?.statusCode == 403;
      setState(
        () =>
            _loadError = isPrivate ? l10n.ridePrivateError : l10n.rideLoadError,
      );
    } finally {
      if (mounted) setState(() => _loadingRide = false);
    }
  }

  Future<void> _pickPhotos() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(
        () => _selectedPhotos.addAll(
          picked.map((file) => CapturedPhoto(file: file)),
        ),
      );
    }
  }

  Future<void> _addCompanion() async {
    final rider = await showRiderPicker(context, friendsOnly: true);
    if (rider == null || !mounted) return;
    if (_selectedCompanions.any((r) => r.id == rider.id)) return;
    setState(() => _selectedCompanions.add(rider));
  }

  void _removeCompanion(UserSummary rider) {
    setState(() => _selectedCompanions.removeWhere((r) => r.id == rider.id));
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      setState(
        () => _saveError = AppLocalizations.of(context)!.rideTitleRequired,
      );
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });

    final repo = context.read<RideRepository>();
    final bikeId = _selectedBike?.id ?? widget.initialBikeId;
    final description = _descriptionController.text.trim();
    final companionUsernames = <String>{
      ..._selectedCompanions.map((c) => c.username).whereType<String>(),
      ...widget.recoveredCompanionUsernames,
    };

    // Persisted before the network call so a kill mid-attempt (or a failure
    // followed by one) still leaves this ride recoverable on next launch
    // (backlog BUG-2). Cleared once `finish()` actually succeeds below.
    await _draftStore.savePendingFinish(
      RidePendingFinish(
        rideId: widget.rideId,
        title: _titleController.text.trim(),
        description: description.isEmpty ? null : description,
        bikeId: bikeId,
        durationSeconds: widget.durationSeconds!,
        distanceMeters: widget.distanceMeters!,
        avgSpeedKmh: widget.avgSpeedKmh!,
        maxSpeedKmh: widget.maxSpeedKmh!,
        track: widget.track!,
        sensorStats: widget.sensorStats,
        photos: _selectedPhotos
            .map((p) => PersistedPhoto(path: p.file.path, lat: p.lat, lng: p.lng))
            .toList(),
        companionUsernames: companionUsernames.toList(),
      ),
    );

    try {
      final result = await repo.finish(
        widget.rideId,
        bikeId: bikeId,
        title: _titleController.text.trim(),
        description: description,
        durationSeconds: widget.durationSeconds!,
        distanceMeters: widget.distanceMeters!,
        avgSpeedKmh: widget.avgSpeedKmh!,
        maxSpeedKmh: widget.maxSpeedKmh!,
        track: widget.track!,
        sensorStats: widget.sensorStats,
      );
      final ride = result.ride;
      _finishConfirmed = true;

      for (final photo in _selectedPhotos) {
        await repo.uploadPhoto(
          ride.id,
          File(photo.file.path),
          lat: photo.lat,
          lng: photo.lng,
        );
      }

      for (final username in companionUsernames) {
        await repo.addParticipant(ride.id, username);
      }

      await _draftStore.clearPendingFinish();

      if (mounted) {
        final navigator = Navigator.of(context);
        navigator.popUntil((route) => route.isFirst);
        navigator.push(
          MaterialPageRoute(
            builder: (_) => RideSummaryScreen.view(
              rideId: ride.id,
              justFinishedRewards: result.rewards,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saveError = apiErrorMessage(context, e));
        if (isNetworkError(e)) _scheduleRetry();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Falls back to a fixed-interval retry alongside the connectivity
  /// listener in [initState], in case a platform misses a connectivity
  /// change event (backlog BUG-2).
  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 20), () {
      if (mounted && !_saving) _save();
    });
  }

  Future<void> _toggleLike() async {
    final ride = _ride;
    if (ride == null) return;
    final repo = context.read<RideRepository>();
    setState(() {
      _ride = ride.copyWith(
        likedByMe: !ride.likedByMe,
        likesCount: ride.likesCount + (ride.likedByMe ? -1 : 1),
      );
    });
    try {
      final result = ride.likedByMe
          ? await repo.unlike(ride.id)
          : await repo.like(ride.id);
      if (mounted) {
        setState(
          () => _ride = _ride!.copyWith(
            likesCount: result.likesCount,
            likedByMe: result.likedByMe,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _ride = ride);
    }
  }

  Future<void> _postComment() async {
    final body = _commentController.text.trim();
    final ride = _ride;
    if (body.isEmpty || ride == null) return;

    setState(() => _postingComment = true);
    try {
      final comment = await context.read<RideRepository>().addComment(
        ride.id,
        body,
      );
      if (!mounted) return;
      setState(() {
        _ride = ride.copyWith(
          comments: [...?ride.comments, comment],
          commentsCount: ride.commentsCount + 1,
        );
        _commentController.clear();
      });
    } catch (_) {
      // Leave the draft in place so the rider can retry.
    } finally {
      if (mounted) setState(() => _postingComment = false);
    }
  }

  Future<void> _deleteComment(RideComment comment) async {
    final ride = _ride;
    if (ride == null) return;
    try {
      await context.read<RideRepository>().deleteComment(comment.id);
      if (!mounted) return;
      setState(() {
        _ride = ride.copyWith(
          comments: ride.comments?.where((c) => c.id != comment.id).toList(),
          commentsCount: ride.commentsCount - 1,
        );
      });
    } catch (_) {
      // Ignore - comment stays visible, user can retry.
    }
  }

  double _elevationGainMeters(List<TrackPoint> points) {
    var gain = 0.0;
    for (var i = 1; i < points.length; i++) {
      final prevAlt = points[i - 1].alt;
      final alt = points[i].alt;
      if (prevAlt != null && alt != null && alt > prevAlt) {
        gain += alt - prevAlt;
      }
    }
    return gain;
  }

  @override
  Widget build(BuildContext context) {
    if (_isSaveMode) return _buildSaveMode(context);
    return _buildViewMode(context);
  }

  Widget _buildSaveMode(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final elevation = _elevationGainMeters(widget.track!);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.rideCompleteTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            RedlSpacing.screenPadding,
            16,
            RedlSpacing.screenPadding,
            32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(RedlRadius.sm),
                child: SizedBox(
                  height: 200,
                  child: RoutePreviewMap(
                    points: widget.track!,
                    avgSpeedKmh: widget.avgSpeedKmh!,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _StatGrid(
                distanceMeters: widget.distanceMeters!,
                durationSeconds: widget.durationSeconds!,
                avgSpeedKmh: widget.avgSpeedKmh!,
                maxSpeedKmh: widget.maxSpeedKmh!,
                elevationMeters: elevation,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _titleController,
                style: RedlText.body(),
                decoration: InputDecoration(labelText: l10n.fieldTitle),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                style: RedlText.body(),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.fieldDescriptionOptional,
                ),
              ),
              const SizedBox(height: 16),
              if (_bikes.isNotEmpty)
                DropdownButtonFormField<Bike?>(
                  initialValue: _selectedBike,
                  dropdownColor: RedlColors.surface2,
                  style: RedlText.body(),
                  decoration: InputDecoration(
                    labelText: l10n.fieldBikeOptional,
                  ),
                  items: [
                    DropdownMenuItem<Bike?>(
                      value: null,
                      child: Text(l10n.bikeNone),
                    ),
                    ..._bikes.map(
                      (b) => DropdownMenuItem<Bike?>(
                        value: b,
                        child: Text(b.displayName),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _selectedBike = value),
                ),
              const SizedBox(height: 20),
              Text(l10n.photosLabel, style: RedlText.eyebrow()),
              const SizedBox(height: 10),
              SizedBox(
                height: 72,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._selectedPhotos.map(
                      (photo) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(RedlRadius.sm),
                          child: Image.file(
                            File(photo.file.path),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _pickPhotos,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: RedlColors.surface2,
                          borderRadius: BorderRadius.circular(RedlRadius.sm),
                        ),
                        child: const Icon(
                          Icons.add_a_photo_outlined,
                          color: RedlColors.textSecondary,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(l10n.ridersLabel, style: RedlText.eyebrow()),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._selectedCompanions.map(
                    (rider) => Chip(
                      backgroundColor: RedlColors.surface2,
                      avatar: CircleAvatar(
                        backgroundColor: RedlColors.surface4,
                        backgroundImage: rider.avatarUrl != null
                            ? NetworkImage(rider.avatarUrl!)
                            : null,
                        child: rider.avatarUrl == null
                            ? const Icon(
                                Icons.person,
                                size: 14,
                                color: RedlColors.baseAlt,
                              )
                            : null,
                      ),
                      label: Text(
                        rider.name,
                        style: RedlText.body(fontSize: 12),
                      ),
                      onDeleted: () => _removeCompanion(rider),
                      deleteIconColor: RedlColors.textSecondary,
                    ),
                  ),
                  ActionChip(
                    backgroundColor: RedlColors.surface2,
                    avatar: const Icon(
                      Icons.add,
                      size: 16,
                      color: RedlColors.baseAlt,
                    ),
                    label: Text(
                      l10n.addRiderLabel,
                      style: RedlText.body(fontSize: 12),
                    ),
                    onPressed: _addCompanion,
                  ),
                ],
              ),
              if (_saveError != null) ...[
                const SizedBox(height: 16),
                Text(
                  _saveError!,
                  style: RedlText.body(
                    fontSize: 13,
                    color: RedlColors.accentTint,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              RedlPrimaryButton(
                label: l10n.actionSaveRide,
                onPressed: _save,
                loading: _saving,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewMode(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loadingRide) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: RedlColors.accent),
        ),
      );
    }
    if (_loadError != null || _ride == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            _loadError ?? l10n.rideNotFound,
            style: RedlText.body(color: RedlColors.textSecondary),
          ),
        ),
      );
    }

    final ride = _ride!;
    final elevation = _elevationGainMeters(ride.routeLine);
    final myUserId = context.watch<AuthProvider>().user?.id;

    return Scaffold(
      appBar: AppBar(title: Text(ride.title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            RedlSpacing.screenPadding,
            8,
            RedlSpacing.screenPadding,
            32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${ride.user.name} · ${formatRelativeDate(context, ride.startedAt)}',
                style: RedlText.meta(),
              ),
              if (ride.participants.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.withRiders(
                    ride.participants.map((r) => r.name).join(', '),
                  ),
                  style: RedlText.meta(color: RedlColors.textSecondary),
                ),
              ],
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(RedlRadius.sm),
                child: SizedBox(
                  height: 220,
                  child: RoutePreviewMap(
                    points: ride.routeLine,
                    interactive: true,
                    avgSpeedKmh: ride.avgSpeedKmh,
                    pois: ride.pointsOfInterest,
                  ),
                ),
              ),
              if (widget.justFinishedRewards != null) ...[
                const SizedBox(height: 20),
                _RewardRevealCard(rewards: widget.justFinishedRewards!),
              ],
              const SizedBox(height: 20),
              _StatGrid(
                distanceMeters: ride.distanceMeters,
                durationSeconds: ride.durationSeconds,
                avgSpeedKmh: ride.avgSpeedKmh,
                maxSpeedKmh: ride.maxSpeedKmh,
                elevationMeters: elevation,
              ),
              const SizedBox(height: 20),
              _RideScoreCard(score: ride.rideScore),
              const SizedBox(height: 16),
              _SpeedScoreCard(
                score: ride.speedScore,
                events: ride.speedingEvents ?? const [],
              ),
              const SizedBox(height: 16),
              RedlSecondaryButton(
                label: l10n.viewDetailedStatsAction,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DetailedStatsScreen(ride: ride),
                  ),
                ),
              ),
              if (ride.description != null && ride.description!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  ride.description!,
                  style: RedlText.body(color: RedlColors.textSecondary),
                ),
              ],
              if (ride.bike != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.two_wheeler_rounded,
                      size: 16,
                      color: RedlColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ride.bike!.displayName,
                      style: RedlText.meta(fontSize: 12),
                    ),
                  ],
                ),
              ],
              if (ride.photos.isNotEmpty) ...[
                const SizedBox(height: 20),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: ride.photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(RedlRadius.sm),
                      child: Image.network(
                        ride.photos[i].url,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
              if (ride.pointsOfInterest.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(l10n.poiSectionLabel, style: RedlText.eyebrow()),
                const SizedBox(height: 10),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: ride.pointsOfInterest.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final poi = ride.pointsOfInterest[i];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(RedlRadius.sm),
                        child: poi.photoUrl != null
                            ? Image.network(
                                poi.photoUrl!,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 100,
                                height: 100,
                                color: RedlColors.surface2,
                                child: const Icon(
                                  Icons.photo_camera_outlined,
                                  color: RedlColors.textMuted,
                                ),
                              ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  GestureDetector(
                    onTap: _toggleLike,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Icon(
                          ride.likedByMe
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 20,
                          color: ride.likedByMe
                              ? RedlColors.accent
                              : RedlColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.likesCount(ride.likesCount),
                          style: RedlText.body(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                    color: RedlColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.commentsCount(ride.commentsCount),
                    style: RedlText.body(fontSize: 13),
                  ),
                ],
              ),
              const Divider(height: 32),
              Text(l10n.commentsLabel, style: RedlText.eyebrow()),
              const SizedBox(height: 12),
              ...?ride.comments?.map(
                (comment) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: RedlColors.surface4,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              comment.user.name,
                              style: RedlText.title(fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              comment.body,
                              style: RedlText.body(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      if (comment.user.id == myUserId)
                        GestureDetector(
                          onTap: () => _deleteComment(comment),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: RedlColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: RedlText.body(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: l10n.addCommentHint,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _postingComment
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: RedlColors.accent,
                          ),
                        )
                      : IconButton(
                          onPressed: _postComment,
                          icon: const Icon(
                            Icons.send,
                            color: RedlColors.accent,
                          ),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.elevationMeters,
  });

  final int distanceMeters;
  final int durationSeconds;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final double elevationMeters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cells = [
      (l10n.statDistance, formatDistanceKm(distanceMeters / 1000)),
      (l10n.statDuration, formatDuration(Duration(seconds: durationSeconds))),
      (l10n.statAvgSpeed, formatSpeedKmh(avgSpeedKmh)),
      (l10n.statElevation, '${elevationMeters.round()} m'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.1,
      children: cells
          .map(
            (c) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: RedlColors.surface2,
                borderRadius: BorderRadius.circular(RedlRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(c.$1, style: RedlText.eyebrow(fontSize: 9)),
                  const SizedBox(height: 6),
                  Text(c.$2, style: RedlText.statValue(fontSize: 19)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SpeedScoreCard extends StatelessWidget {
  const _SpeedScoreCard({required this.score, required this.events});

  final int? score;
  final List<SpeedingEvent> events;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RedlColors.surface2,
        borderRadius: BorderRadius.circular(RedlRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.speedScoreLabel,
                      style: RedlText.eyebrow(fontSize: 9),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      score != null ? '$score' : '—',
                      style: RedlText.statValue(
                        fontSize: 26,
                        color: score != null
                            ? scoreToColor(score!)
                            : RedlColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      score != null
                          ? l10n.speedScoreCaption
                          : l10n.speedScoreNoData,
                      style: RedlText.body(
                        fontSize: 11,
                        color: RedlColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (events.isNotEmpty) ...[
            const Divider(height: 24),
            Text(
              l10n.speedingEventsLabel,
              style: RedlText.eyebrow(fontSize: 9),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.speedingEventsCount(events.length),
              style: RedlText.body(fontSize: 12),
            ),
            const SizedBox(height: 10),
            ...events.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  l10n.speedingEventDetail(
                    formatSpeedKmh(event.limitKmh),
                    formatSpeedKmh(event.maxSpeedKmh),
                    formatDuration(Duration(seconds: event.durationSeconds)),
                  ),
                  style: RedlText.body(
                    fontSize: 12,
                    color: RedlColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The one-time reveal of what a just-finished ride earned: XP, level
/// (with a progress bar when it changed), and any newly unlocked badges -
/// only shown right after PATCH /rides/{id}/finish, never on a later visit
/// to the same ride (project doc 8.2).
class _RewardRevealCard extends StatelessWidget {
  const _RewardRevealCard({required this.rewards});

  final RideRewardOutcome rewards;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RedlColors.surface2,
        borderRadius: BorderRadius.circular(RedlRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.xpGainedLabel,
                      style: RedlText.eyebrow(fontSize: 9),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '+${rewards.xpGained} XP',
                      style: RedlText.statValue(
                        fontSize: 22,
                        color: RedlColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(l10n.levelLabel, style: RedlText.eyebrow(fontSize: 9)),
                  const SizedBox(height: 6),
                  Text(
                    '${rewards.level}',
                    style: RedlText.statValue(fontSize: 22),
                  ),
                ],
              ),
            ],
          ),
          if (rewards.leveledUp) ...[
            const SizedBox(height: 10),
            Text(
              l10n.leveledUpMessage(rewards.level),
              style: RedlText.body(fontSize: 12, color: RedlColors.accentTint),
            ),
          ],
          if (rewards.territoryCellsTouched > 0) ...[
            const SizedBox(height: 10),
            Text(
              l10n.territoriesTouchedMessage(rewards.territoryCellsTouched),
              style: RedlText.body(
                fontSize: 12,
                color: RedlColors.textSecondary,
              ),
            ),
          ],
          if (rewards.newBadges.isNotEmpty) ...[
            const Divider(height: 24),
            Text(l10n.newBadgesLabel, style: RedlText.eyebrow(fontSize: 9)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: rewards.newBadges
                  .map(
                    (badge) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: RedlColors.surface4,
                        borderRadius: BorderRadius.circular(RedlRadius.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.military_tech,
                            size: 16,
                            color: RedlColors.accent,
                          ),
                          const SizedBox(width: 6),
                          Text(badge.name, style: RedlText.body(fontSize: 12)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// The ride's persisted Ride Score (distance + sinuosity + POI + territory,
/// see project doc 9.1) - unlike [_RewardRevealCard], shown every time the
/// ride's detail is viewed, not just right after finishing it.
class _RideScoreCard extends StatelessWidget {
  const _RideScoreCard({required this.score});

  final int? score;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RedlColors.surface2,
        borderRadius: BorderRadius.circular(RedlRadius.sm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.rideScoreLabel, style: RedlText.eyebrow(fontSize: 9)),
                const SizedBox(height: 6),
                Text(
                  score != null ? '$score' : '—',
                  style: RedlText.statValue(
                    fontSize: 26,
                    color: RedlColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
