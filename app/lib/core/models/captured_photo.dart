import 'package:image_picker/image_picker.dart';

/// A photo picked or shot by the rider, awaiting upload once the ride is
/// saved. [lat]/[lng] are the rider's GPS position at capture time when
/// shot mid-ride (null for photos picked from the gallery afterward).
class CapturedPhoto {
  const CapturedPhoto({required this.file, this.lat, this.lng});

  final XFile file;
  final double? lat;
  final double? lng;
}
