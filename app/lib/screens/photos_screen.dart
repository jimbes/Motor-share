import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/models/my_photo.dart';
import '../core/repositories/ride_repository.dart';
import '../l10n/app_localizations.dart';
import '../theme/redl_colors.dart';
import '../theme/redl_spacing.dart';
import '../theme/redl_text_styles.dart';
import 'ride_summary_screen.dart';

enum _PhotosView { grid, map }

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key});

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  final _scrollController = ScrollController();
  final List<MyPhoto> _photos = [];
  _PhotosView _view = _PhotosView.grid;
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
      final page = await context.read<RideRepository>().myPhotos(page: 1);
      setState(() {
        _photos
          ..clear()
          ..addAll(page.photos);
        _page = 1;
        _hasMore = page.hasMorePages;
      });
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.photosLoadError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final page = await context.read<RideRepository>().myPhotos(page: _page + 1);
      setState(() {
        _photos.addAll(page.photos);
        _page += 1;
        _hasMore = page.hasMorePages;
      });
    } catch (_) {
      // Silently keep current state - user can retry by scrolling again.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// The map wants the whole picture at once rather than growing as the
  /// user scrolls, so pull in every remaining page the first time it's shown.
  Future<void> _showMap() async {
    setState(() => _view = _PhotosView.map);
    while (_hasMore && mounted) {
      await _loadMore();
    }
  }

  void _openRide(int rideId) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => RideSummaryScreen.view(rideId: rideId)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.photosTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: RedlSpacing.screenPadding),
            child: SegmentedButton<_PhotosView>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: _PhotosView.grid, icon: const Icon(Icons.grid_view_rounded, size: 16)),
                ButtonSegment(value: _PhotosView.map, icon: const Icon(Icons.map_outlined, size: 16)),
              ],
              selected: {_view},
              onSelectionChanged: (selection) {
                if (selection.first == _PhotosView.map) {
                  _showMap();
                } else {
                  setState(() => _view = _PhotosView.grid);
                }
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: RedlColors.accent))
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : _photos.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            l10n.photosEmpty,
                            textAlign: TextAlign.center,
                            style: RedlText.body(color: RedlColors.textSecondary),
                          ),
                        ),
                      )
                    : _view == _PhotosView.grid
                        ? _PhotosGrid(
                            photos: _photos,
                            scrollController: _scrollController,
                            loadingMore: _loadingMore,
                            onTapPhoto: (photo) => _openRide(photo.rideId),
                          )
                        : _PhotosMap(photos: _photos, onTapPhoto: (photo) => _openRide(photo.rideId)),
      ),
    );
  }
}

class _PhotosGrid extends StatelessWidget {
  const _PhotosGrid({
    required this.photos,
    required this.scrollController,
    required this.loadingMore,
    required this.onTapPhoto,
  });

  final List<MyPhoto> photos;
  final ScrollController scrollController;
  final bool loadingMore;
  final ValueChanged<MyPhoto> onTapPhoto;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
      itemCount: photos.length + (loadingMore ? 3 : 0),
      itemBuilder: (context, index) {
        if (index >= photos.length) {
          return Container(color: RedlColors.surface2);
        }
        final photo = photos[index];
        return GestureDetector(
          onTap: () => onTapPhoto(photo),
          child: Image.network(
            photo.url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: RedlColors.surface2,
              child: const Icon(Icons.broken_image_outlined, color: RedlColors.textSecondary),
            ),
          ),
        );
      },
    );
  }
}

class _PhotosMap extends StatelessWidget {
  const _PhotosMap({required this.photos, required this.onTapPhoto});

  final List<MyPhoto> photos;
  final ValueChanged<MyPhoto> onTapPhoto;

  @override
  Widget build(BuildContext context) {
    final located = photos.where((p) => p.hasLocation).toList();

    if (located.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            AppLocalizations.of(context)!.photosMapEmpty,
            textAlign: TextAlign.center,
            style: RedlText.body(color: RedlColors.textSecondary),
          ),
        ),
      );
    }

    final points = located.map((p) => LatLng(p.lat!, p.lng!)).toList();
    final bounds = LatLngBounds.fromPoints(points);

    return FlutterMap(
      options: MapOptions(initialCameraFit: CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48))),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.besse.redl',
        ),
        MarkerLayer(
          markers: located
              .map((photo) => Marker(
                    point: LatLng(photo.lat!, photo.lng!),
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      onTap: () => onTapPhoto(photo),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: RedlColors.accent, width: 2),
                          image: DecorationImage(image: NetworkImage(photo.url), fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
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
          TextButton(onPressed: onRetry, child: Text(AppLocalizations.of(context)!.actionRetry)),
        ],
      ),
    );
  }
}
