import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/user_summary.dart';
import '../core/repositories/user_repository.dart';
import '../l10n/app_localizations.dart';
import '../theme/redl_colors.dart';
import '../theme/redl_spacing.dart';
import '../theme/redl_text_styles.dart';

/// Presents a searchable rider picker as a modal bottom sheet.
/// Returns the selected [UserSummary], or null if dismissed.
///
/// [friendsOnly] narrows the search to the caller's mutual-follow friends -
/// used for ride-companion tagging, since only friends can be tagged.
Future<UserSummary?> showRiderPicker(BuildContext context, {bool friendsOnly = false}) {
  return showModalBottomSheet<UserSummary>(
    context: context,
    isScrollControlled: true,
    backgroundColor: RedlColors.surface1,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _RiderPickerSheet(friendsOnly: friendsOnly),
  );
}

class _RiderPickerSheet extends StatefulWidget {
  const _RiderPickerSheet({required this.friendsOnly});

  final bool friendsOnly;

  @override
  State<_RiderPickerSheet> createState() => _RiderPickerSheetState();
}

class _RiderPickerSheetState extends State<_RiderPickerSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<UserSummary> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final results = await context.read<UserRepository>().search(query, friendsOnly: widget.friendsOnly);
      if (mounted) setState(() => _results = results);
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(RedlSpacing.screenPadding, 20, RedlSpacing.screenPadding, 12),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: _onChanged,
                  style: RedlText.body(),
                  decoration: InputDecoration(labelText: l10n.searchHint),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: RedlColors.accent))
                    : _results.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: RedlSpacing.screenPadding),
                              child: Text(
                                _controller.text.trim().isEmpty
                                    ? (widget.friendsOnly ? l10n.companionPickerFriendsOnlyHint : l10n.searchPrompt)
                                    : l10n.searchEmpty,
                                textAlign: TextAlign.center,
                                style: RedlText.body(color: RedlColors.textSecondary),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (_, i) {
                              final rider = _results[i];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: RedlSpacing.screenPadding),
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: RedlColors.surface4,
                                  backgroundImage: rider.avatarUrl != null ? NetworkImage(rider.avatarUrl!) : null,
                                  child: rider.avatarUrl == null ? const Icon(Icons.person, color: RedlColors.baseAlt) : null,
                                ),
                                title: Text(rider.name, style: RedlText.title(fontSize: 14)),
                                subtitle: rider.username != null ? Text('@${rider.username}', style: RedlText.meta()) : null,
                                onTap: () => Navigator.of(context).pop(rider),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
