import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/user_summary.dart';
import '../core/repositories/user_repository.dart';
import '../l10n/app_localizations.dart';
import '../theme/redl_colors.dart';
import '../theme/redl_spacing.dart';
import '../theme/redl_text_styles.dart';
import 'rider_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<UserSummary> _results = [];
  bool _loading = false;
  bool _searched = false;

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
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final results = await context.read<UserRepository>().search(query);
      if (mounted) {
        setState(() {
          _results = results;
          _searched = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          style: RedlText.body(),
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            hintStyle: RedlText.body(color: RedlColors.textSecondary),
            border: InputBorder.none,
          ),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: RedlColors.accent))
            : !_searched
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(l10n.searchPrompt, textAlign: TextAlign.center, style: RedlText.body(color: RedlColors.textSecondary)),
                    ),
                  )
                : _results.isEmpty
                    ? Center(child: Text(l10n.searchEmpty, style: RedlText.body(color: RedlColors.textSecondary)))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: RedlColors.divider),
                        itemBuilder: (_, i) {
                          final rider = _results[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: RedlSpacing.screenPadding),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: RedlColors.surface4,
                              backgroundImage: rider.avatarUrl != null ? NetworkImage(rider.avatarUrl!) : null,
                              child: rider.avatarUrl == null ? const Icon(Icons.person, color: RedlColors.baseAlt) : null,
                            ),
                            title: Text(rider.name, style: RedlText.title(fontSize: 14)),
                            subtitle: rider.username != null ? Text('@${rider.username}', style: RedlText.meta()) : null,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => RiderProfileScreen(username: rider.username!)),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
