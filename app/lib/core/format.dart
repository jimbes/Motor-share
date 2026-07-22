String formatDistanceKm(double km) => '${km.toStringAsFixed(km < 10 ? 2 : 1)} km';

String formatDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }
  if (minutes > 0) {
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }
  return '${seconds}s';
}

String formatSpeedKmh(double kmh) => '${kmh.toStringAsFixed(0)} km/h';

String formatRelativeDate(DateTime dateTime) {
  final now = DateTime.now();
  final local = dateTime.toLocal();
  final difference = now.difference(local);

  if (difference.inDays == 0 && now.day == local.day) return 'Today';
  if (difference.inDays == 1 || (difference.inDays == 0 && now.day != local.day)) return 'Yesterday';
  if (difference.inDays < 7) return '${difference.inDays} days ago';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}
