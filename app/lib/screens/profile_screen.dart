import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/bike.dart';
import '../core/models/reward_summary.dart';
import '../core/models/rider_stats.dart';
import '../core/repositories/bike_repository.dart';
import '../core/repositories/reward_repository.dart';
import '../core/repositories/ride_repository.dart';
import '../l10n/app_localizations.dart';
import '../state/auth_provider.dart';
import '../state/locale_provider.dart';
import '../theme/redl_colors.dart';
import '../theme/redl_spacing.dart';
import '../theme/redl_text_styles.dart';
import 'badge_catalog_screen.dart';
import 'edit_profile_screen.dart';
import 'garage_screen.dart';
import 'territory_map_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  RiderStats? _stats;
  RewardSummary? _rewards;
  List<Bike> _bikes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        context.read<RideRepository>().myStats(),
        context.read<BikeRepository>().list(),
        context.read<RewardRepository>().mine(),
      ]);
      if (mounted) {
        setState(() {
          _stats = results[0] as RiderStats;
          _bikes = results[1] as List<Bike>;
          _rewards = results[2] as RewardSummary;
        });
      }
    } catch (_) {
      // Non-fatal - profile still renders with whatever loaded.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showLanguagePicker(BuildContext context) async {
    final localeProvider = context.read<LocaleProvider>();
    final current = localeProvider.locale;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: RedlColors.surface1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext)!;
        Widget option(String label, Locale? locale) {
          final selected = current?.languageCode == locale?.languageCode;
          return ListTile(
            title: Text(label, style: RedlText.body()),
            trailing: selected ? const Icon(Icons.check, color: RedlColors.accent) : null,
            onTap: () {
              localeProvider.setLocale(locale);
              Navigator.of(sheetContext).pop();
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(RedlSpacing.screenPadding, 20, RedlSpacing.screenPadding, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l10n.languageLabel, style: RedlText.eyebrow()),
                ),
              ),
              option('English', const Locale('en')),
              option('Français', const Locale('fr')),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = context.watch<AuthProvider>().user;
    final memberSince = user?.createdAt?.year.toString() ?? '—';

    String? bannerPhotoUrl;
    for (final bike in _bikes) {
      if (bike.isDefault && bike.photoUrl != null) {
        bannerPhotoUrl = bike.photoUrl;
        break;
      }
    }

    return Scaffold(
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: 164,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 60,
                      left: 0,
                      right: 0,
                      height: 120,
                      child: Container(
                        decoration: BoxDecoration(
                          color: RedlColors.accent,
                          image: bannerPhotoUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(bannerPhotoUrl),
                                  fit: BoxFit.cover,
                                  colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.35), BlendMode.darken),
                                )
                              : null,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 60 + 120 - 44,
                      left: RedlSpacing.screenPadding,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: RedlColors.surface4,
                            shape: BoxShape.circle,
                            border: Border.all(color: RedlColors.base, width: 4),
                            image: user?.avatarUrl != null
                                ? DecorationImage(image: NetworkImage(user!.avatarUrl!), fit: BoxFit.cover)
                                : null,
                          ),
                          child: user?.avatarUrl == null
                              ? const Icon(Icons.person, color: RedlColors.baseAlt, size: 36)
                              : null,
                        ),
                      ),
                    ),
                    Positioned(
                      right: RedlSpacing.screenPadding,
                      top: 72,
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                            icon: const Icon(Icons.edit_outlined, color: RedlColors.baseAlt),
                            tooltip: l10n.editProfileTitle,
                          ),
                          IconButton(
                            onPressed: () => _showLanguagePicker(context),
                            icon: const Icon(Icons.language, color: RedlColors.baseAlt),
                            tooltip: l10n.languageLabel,
                          ),
                          IconButton(
                            onPressed: () => context.read<AuthProvider>().logout(),
                            icon: const Icon(Icons.logout, color: RedlColors.baseAlt),
                            tooltip: l10n.logOut,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: RedlSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? '', style: RedlText.title(fontSize: 16)),
                    if (user?.username != null) ...[
                      const SizedBox(height: 2),
                      Text('@${user!.username}', style: RedlText.meta(color: RedlColors.textSecondary)),
                    ],
                    const SizedBox(height: 4),
                    Text(l10n.riderSince(memberSince), style: RedlText.meta()),
                    const SizedBox(height: 20),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator(color: RedlColors.accent)),
                      )
                    else
                      Container(
                        decoration: const BoxDecoration(
                          border: Border.symmetric(horizontal: BorderSide(color: RedlColors.divider)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          children: [
                            _ProfileStat(label: l10n.statRides, value: '${_stats?.ridesCount ?? 0}'),
                            _ProfileStat(label: l10n.statDistance, value: '${(_stats?.distanceKm ?? 0).toStringAsFixed(0)} km'),
                            _ProfileStat(label: l10n.feedThisWeek, value: '${(_stats?.weekDistanceKm ?? 0).toStringAsFixed(0)} km'),
                          ],
                        ),
                      ),
                    if (_rewards != null) ...[
                      const SizedBox(height: 24),
                      Text(l10n.profileRewardsLabel, style: RedlText.eyebrow()),
                      const SizedBox(height: 12),
                      _RewardsBlock(rewards: _rewards!),
                    ],
                    const SizedBox(height: 24),
                    Text(l10n.vehiclesLabel, style: RedlText.eyebrow()),
                    const SizedBox(height: 12),
                    if (_bikes.isEmpty)
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GarageScreen())).then((_) => _load()),
                        child: Text(l10n.addBikeToGarage, style: RedlText.body(fontSize: 13, color: RedlColors.textSecondary)),
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _bikes
                            .map((bike) => GestureDetector(
                                  onTap: () => Navigator.of(context)
                                      .push(MaterialPageRoute(builder: (_) => const GarageScreen()))
                                      .then((_) => _load()),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(color: RedlColors.surface2, borderRadius: BorderRadius.circular(RedlRadius.sm)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 26,
                                          decoration: BoxDecoration(color: RedlColors.surface4, borderRadius: BorderRadius.circular(RedlRadius.sm)),
                                          child: const Icon(Icons.two_wheeler_rounded, size: 16, color: RedlColors.baseAlt),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(bike.displayName, style: RedlText.body(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
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

/// XP/level/badges/territories summary (REDL project doc, section 8.2).
class _RewardsBlock extends StatelessWidget {
  const _RewardsBlock({required this.rewards});

  final RewardSummary rewards;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: const BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: RedlColors.divider))),
          child: Row(
            children: [
              _ProfileStat(label: l10n.profileXpLabel, value: '${rewards.xpTotal}'),
              _ProfileStat(label: l10n.profileLevelLabel, value: '${rewards.level}'),
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TerritoryMapScreen())),
                child: _ProfileStat(label: l10n.profileTerritoriesLabel, value: '${rewards.territoriesOwnedCount}'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (rewards.badges.isNotEmpty)
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: rewards.badges.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(color: RedlColors.surface2, shape: BoxShape.circle),
                child: const Icon(Icons.military_tech, color: RedlColors.accent, size: 24),
              ),
            ),
          ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BadgeCatalogScreen())),
          child: Text(l10n.profileViewBadgesAction, style: RedlText.body(fontSize: 13, color: RedlColors.textSecondary)),
        ),
      ],
    );
  }
}
