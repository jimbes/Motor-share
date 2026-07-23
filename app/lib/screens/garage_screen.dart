import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/bike.dart';
import '../core/repositories/bike_repository.dart';
import '../l10n/app_localizations.dart';
import '../theme/redl_colors.dart';
import '../theme/redl_spacing.dart';
import '../theme/redl_text_styles.dart';
import '../widgets/bike_form_sheet.dart';

class GarageScreen extends StatefulWidget {
  const GarageScreen({super.key});

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
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
      final bikes = await context.read<BikeRepository>().list();
      if (mounted) setState(() => _bikes = bikes);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addBike() async {
    final saved = await showBikeForm(context);
    if (saved != null) _load();
  }

  Future<void> _editBike(Bike bike) async {
    final saved = await showBikeForm(context, existing: bike);
    if (saved != null) _load();
  }

  Future<void> _setDefault(Bike bike) async {
    if (bike.isDefault) return;
    try {
      await context.read<BikeRepository>().setDefault(bike.id);
      _load();
    } catch (_) {
      // Ignore - the bike list stays as-is, user can retry.
    }
  }

  Future<void> _deleteBike(Bike bike) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: RedlColors.surface2,
        title: Text(l10n.removeBikeTitle(bike.displayName), style: RedlText.title(fontSize: 15)),
        content: Text(l10n.removeBikeContent, style: RedlText.body(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.actionRemove)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<BikeRepository>().delete(bike.id);
      _load();
    } catch (_) {
      // Ignore - the bike stays listed, user can retry.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.garageTitle),
        actions: [IconButton(onPressed: _addBike, icon: const Icon(Icons.add))],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: RedlColors.accent))
            : RefreshIndicator(
                onRefresh: _load,
                child: _bikes.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.symmetric(horizontal: RedlSpacing.screenPadding, vertical: 80),
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Text(l10n.noBikesYet, style: RedlText.body(color: RedlColors.textSecondary)),
                                const SizedBox(height: 12),
                                TextButton(onPressed: _addBike, child: Text(l10n.addFirstBike)),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(RedlSpacing.screenPadding),
                        itemCount: _bikes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final bike = _bikes[i];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: RedlColors.surface2, borderRadius: BorderRadius.circular(RedlRadius.sm)),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(RedlRadius.sm),
                                  child: Container(
                                    width: 44,
                                    height: 32,
                                    color: RedlColors.surface4,
                                    child: bike.photoUrl != null
                                        ? Image.network(bike.photoUrl!, fit: BoxFit.cover)
                                        : const Icon(Icons.two_wheeler_rounded, color: RedlColors.baseAlt, size: 20),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(child: Text(bike.displayName, style: RedlText.title(fontSize: 14))),
                                          if (bike.isDefault) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: RedlColors.accent.withValues(alpha: 0.18),
                                                borderRadius: BorderRadius.circular(RedlRadius.sm),
                                              ),
                                              child: Text(l10n.defaultBikeLabel, style: RedlText.eyebrow(fontSize: 8, color: RedlColors.accent)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        [
                                          '${bike.brand} ${bike.model}',
                                          if (bike.year != null) '${bike.year}',
                                          if (bike.engineCc != null) '${bike.engineCc} cc',
                                        ].join(' · '),
                                        style: RedlText.meta(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _setDefault(bike),
                                  tooltip: l10n.setAsDefaultTooltip,
                                  icon: Icon(
                                    bike.isDefault ? Icons.star : Icons.star_border,
                                    size: 18,
                                    color: bike.isDefault ? RedlColors.accent : RedlColors.textSecondary,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _editBike(bike),
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: RedlColors.textSecondary),
                                ),
                                IconButton(
                                  onPressed: () => _deleteBike(bike),
                                  icon: const Icon(Icons.delete_outline, size: 18, color: RedlColors.textSecondary),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}
