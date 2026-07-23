import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/models/bike.dart';
import '../core/repositories/bike_repository.dart';
import '../l10n/app_localizations.dart';
import '../theme/redl_colors.dart';
import '../theme/redl_spacing.dart';
import '../theme/redl_text_styles.dart';
import 'redl_buttons.dart';

/// Presents the add/edit bike form as a modal bottom sheet.
/// Returns the created/updated [Bike] on success, or null if dismissed.
Future<Bike?> showBikeForm(BuildContext context, {Bike? existing}) {
  return showModalBottomSheet<Bike>(
    context: context,
    isScrollControlled: true,
    backgroundColor: RedlColors.surface1,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _BikeFormSheet(existing: existing),
  );
}

class _BikeFormSheet extends StatefulWidget {
  const _BikeFormSheet({this.existing});

  final Bike? existing;

  @override
  State<_BikeFormSheet> createState() => _BikeFormSheetState();
}

class _BikeFormSheetState extends State<_BikeFormSheet> {
  late final _brandController = TextEditingController(text: widget.existing?.brand ?? '');
  late final _modelController = TextEditingController(text: widget.existing?.model ?? '');
  late final _nicknameController = TextEditingController(text: widget.existing?.nickname ?? '');
  late final _yearController = TextEditingController(text: widget.existing?.year?.toString() ?? '');
  late final _ccController = TextEditingController(text: widget.existing?.engineCc?.toString() ?? '');
  XFile? _pickedPhoto;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _nicknameController.dispose();
    _yearController.dispose();
    _ccController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final l10n = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: RedlColors.surface1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) {
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
    if (picked != null && mounted) setState(() => _pickedPhoto = picked);
  }

  Future<void> _save() async {
    if (_brandController.text.trim().isEmpty || _modelController.text.trim().isEmpty) {
      setState(() => _error = AppLocalizations.of(context)!.bikeBrandModelRequired);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final bike = Bike(
      id: widget.existing?.id ?? 0,
      brand: _brandController.text.trim(),
      model: _modelController.text.trim(),
      nickname: _nicknameController.text.trim().isEmpty ? null : _nicknameController.text.trim(),
      year: int.tryParse(_yearController.text.trim()),
      engineCc: int.tryParse(_ccController.text.trim()),
    );

    try {
      final repo = context.read<BikeRepository>();
      var saved = widget.existing != null ? await repo.update(widget.existing!.id, bike) : await repo.create(bike);

      final photo = _pickedPhoto;
      if (photo != null) {
        saved = await repo.uploadPhoto(saved.id, File(photo.path));
      }

      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(context, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final existingPhotoUrl = widget.existing?.photoUrl;

    return Padding(
      padding: EdgeInsets.only(
        left: RedlSpacing.screenPadding,
        right: RedlSpacing.screenPadding,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing != null ? l10n.editBikeTitle : l10n.addBikeTitle, style: RedlText.title(fontSize: 16)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickPhoto,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(RedlRadius.sm),
                child: Container(
                  height: 120,
                  color: RedlColors.surface2,
                  child: _pickedPhoto != null
                      ? Image.file(File(_pickedPhoto!.path), fit: BoxFit.cover, width: double.infinity)
                      : existingPhotoUrl != null
                          ? Image.network(existingPhotoUrl, fit: BoxFit.cover, width: double.infinity)
                          : Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_a_photo_outlined, color: RedlColors.textSecondary, size: 22),
                                  const SizedBox(height: 6),
                                  Text(l10n.addBikePhotoLabel, style: RedlText.meta()),
                                ],
                              ),
                            ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(controller: _brandController, style: RedlText.body(), decoration: InputDecoration(labelText: l10n.fieldBrand)),
            const SizedBox(height: 14),
            TextField(controller: _modelController, style: RedlText.body(), decoration: InputDecoration(labelText: l10n.fieldModel)),
            const SizedBox(height: 14),
            TextField(controller: _nicknameController, style: RedlText.body(), decoration: InputDecoration(labelText: l10n.fieldNicknameOptional)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _yearController,
                    style: RedlText.body(),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.fieldYear),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _ccController,
                    style: RedlText.body(),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.fieldEngineCc),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: RedlText.body(fontSize: 13, color: RedlColors.accentTint)),
            ],
            const SizedBox(height: 20),
            RedlPrimaryButton(label: l10n.actionSave, onPressed: _save, loading: _saving),
          ],
        ),
      ),
    );
  }
}
