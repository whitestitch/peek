/// lib/core/constants.dart
/// Set this via `--dart-define=USE_FIREBASE_EMULATOR=true` when you
/// run `flutter run` against your local emulators.
const bool useFirebaseEmulator = bool.fromEnvironment(
  'USE_FIREBASE_EMULATOR',
  defaultValue: false,
);
