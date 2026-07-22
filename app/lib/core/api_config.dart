/// Backend base URL, overridable at build/run time:
///   flutter run --dart-define=API_BASE_URL=https://api.your-domain.com/api
///
/// Defaults to the Android emulator's loopback alias to a host machine
/// running `php artisan serve` (10.0.2.2 -> host's 127.0.0.1). On a
/// physical device this must be overridden to either your laptop's LAN IP
/// (local Docker testing) or the distant server's public URL.
class ApiConfig {
  ApiConfig._();

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );
}
