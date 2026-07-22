# REDL — Flutter app

"Track every apex." A Strava-style motorbike ride tracker: GPS recording,
route maps drawn with OpenStreetMap (via `flutter_map` — **no Google Maps
SDK, no paid map service anywhere in this app**), a social feed (likes,
comments, photos), and a garage for your bikes.

Branding, colors, typography and the five core screens follow the REDL
design handoff (see `DESIGN.md` at the repo root for the full token
reference).

## Requirements

- Flutter SDK (stable channel) — https://docs.flutter.dev/get-started/install
- Android Studio + Android SDK, for building/running on Android
- A running instance of the `backend/` API (see `backend/DEPLOY.md`)

## Setup

```bash
flutter pub get
```

## Running

The backend URL is a compile-time constant, overridable via `--dart-define`:

```bash
# Android emulator, backend running locally via `php artisan serve`
# (10.0.2.2 is the emulator's alias for the host machine's localhost)
flutter run

# Physical phone on the same Wi-Fi as your laptop, local Docker backend
flutter run --dart-define=API_BASE_URL=http://<your-laptop-LAN-IP>:8000/api

# Pointed at the distant server once it's deployed
flutter run --dart-define=API_BASE_URL=https://api.your-domain.com/api
```

Default (no flag): `http://10.0.2.2:8000/api`.

## Testing

```bash
flutter analyze
flutter test
```

## Project structure

```
lib/
  core/            API client, repositories, data models, formatting helpers
  state/           Provider ChangeNotifiers (auth session, ride recording)
  theme/           REDL colors, typography, spacing/radius tokens
  widgets/         Reusable components (buttons, logo, ride card, route map...)
  screens/         Onboarding, Login, Register, Feed, Record, Ride Summary,
                   Garage, Profile
```

## Notes / follow-ups for a next iteration

- The app launcher icon is still the Flutter default — swap in the REDL mark
  (`assets/images/redl-icon-bordeaux.svg`) via `flutter_launcher_icons` when
  ready to distribute a build.
- Live GPS recording uses `geolocator`'s Android foreground-service /
  notification support to keep tracking while the screen is off. This needs
  a real on-device test pass (background tracking behavior can't be verified
  in an emulator/CI environment).
- `tile.openstreetmap.org` is used for map tiles, which is fine for
  development but has a strict usage policy for production traffic at scale
  — see https://operations.osmfoundation.org/policies/tiles/. For a real
  launch, switch to a compliant self-hosted tile server or an open-data
  tile provider.
