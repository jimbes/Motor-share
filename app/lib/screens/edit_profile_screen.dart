import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../l10n/app_localizations.dart';
import '../state/auth_provider.dart';
import '../theme/redl_colors.dart';
import '../theme/redl_spacing.dart';
import '../theme/redl_text_styles.dart';
import '../widgets/redl_buttons.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: context.read<AuthProvider>().user?.name ?? '');
  late final _usernameController = TextEditingController(text: context.read<AuthProvider>().user?.username ?? '');
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _error;
  static final _usernamePattern = RegExp(r'^[a-zA-Z0-9_]+$');

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatarSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: RedlColors.surface1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext)!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: RedlColors.baseAlt),
                title: Text(l10n.actionTakePhoto, style: RedlText.body()),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: RedlColors.baseAlt),
                title: Text(l10n.actionChooseFromGallery, style: RedlText.body()),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      await context.read<AuthProvider>().uploadAvatar(File(picked.path));
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(context, e));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final username = _usernameController.text.trim();
      await context.read<AuthProvider>().updateProfile(
            name: _nameController.text.trim(),
            username: username.isEmpty ? null : username,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(context, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editProfileTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: RedlSpacing.screenPadding, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _uploadingAvatar ? null : _pickAvatarSource,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: RedlColors.surface4,
                            shape: BoxShape.circle,
                            image: user?.avatarUrl != null
                                ? DecorationImage(image: NetworkImage(user!.avatarUrl!), fit: BoxFit.cover)
                                : null,
                          ),
                          child: user?.avatarUrl == null
                              ? const Icon(Icons.person, color: RedlColors.baseAlt, size: 40)
                              : null,
                        ),
                        if (_uploadingAvatar)
                          const CircularProgressIndicator(color: RedlColors.accent)
                        else
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: const BoxDecoration(
                                color: RedlColors.accent,
                                shape: BoxShape.circle,
                                border: Border.fromBorderSide(BorderSide(color: RedlColors.base, width: 2)),
                              ),
                              child: const Icon(Icons.edit, color: RedlColors.baseAlt, size: 14),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _uploadingAvatar ? null : _pickAvatarSource,
                    child: Text(l10n.changePhotoLabel),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  style: RedlText.body(),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l10n.fieldName),
                  validator: (value) => (value == null || value.trim().isEmpty) ? l10n.fieldNameRequired : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  style: RedlText.body(),
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(labelText: l10n.fieldUsername, helperText: l10n.fieldUsernameHelper, prefixText: '@'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    return _usernamePattern.hasMatch(value.trim()) ? null : l10n.fieldUsernameInvalid;
                  },
                  onFieldSubmitted: (_) => _save(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: RedlText.body(fontSize: 13, color: RedlColors.accentTint)),
                ],
                const SizedBox(height: 24),
                RedlPrimaryButton(label: l10n.actionSave, onPressed: _save, loading: _saving),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
