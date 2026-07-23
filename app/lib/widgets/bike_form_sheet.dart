import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/models/bike.dart';
import '../core/models/bike_photo.dart';
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
  List<BikePhoto> _existingPhotos = [];
  final List<XFile> _pickedPhotos = [];
  bool _saving = false;
  String? _error;

  int? get _bikeId => widget.existing?.id;

  @override
  void initState() {
    super.initState();
    _existingPhotos = List.of(widget.existing?.photos ?? const []);
  }

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
    if (picked != null && mounted) setState(() => _pickedPhotos.add(picked));
  }

  void _removePickedPhoto(XFile photo) {
    setState(() => _pickedPhotos.remove(photo));
  }

  Future<void> _removeExistingPhoto(BikePhoto photo) async {
    final bikeId = _bikeId;
    if (bikeId == null) return;
    final previous = List.of(_existingPhotos);
    setState(() => _existingPhotos.removeWhere((p) => p.id == photo.id));
    try {
      await context.read<BikeRepository>().removePhoto(bikeId, photo.id);
    } catch (_) {
      if (mounted) setState(() => _existingPhotos = List.of(previous));
    }
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

      for (final photo in _pickedPhotos) {
        saved = await repo.addPhoto(saved.id, File(photo.path));
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
            SizedBox(
              height: 88,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._existingPhotos.map((photo) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _PhotoThumb(
                          image: NetworkImage(photo.url),
                          onRemove: () => _removeExistingPhoto(photo),
                        ),
                      )),
                  ..._pickedPhotos.map((photo) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _PhotoThumb(
                          image: FileImage(File(photo.path)),
                          onRemove: () => _removePickedPhoto(photo),
                        ),
                      )),
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(color: RedlColors.surface2, borderRadius: BorderRadius.circular(RedlRadius.sm)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo_outlined, color: RedlColors.textSecondary, size: 22),
                          const SizedBox(height: 6),
                          Text(l10n.addBikePhotoLabel, style: RedlText.meta(fontSize: 10), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                ],
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

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.image, required this.onRemove});

  final ImageProvider image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(RedlRadius.sm),
          child: Image(image: image, width: 88, height: 88, fit: BoxFit.cover),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(color: RedlColors.base, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 14, color: RedlColors.baseAlt),
            ),
          ),
        ),
      ],
    );
  }
}
