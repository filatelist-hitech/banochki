# Проверки R1/R2

## Команды

Запускать из `apps/mobile`:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test/r1_local_flow_test.dart -d <device-id>
flutter build apk --debug
flutter build ios --simulator --debug
```

## Покрытие

- unit: reducer/status/search normalization;
- repository: quantity events, ordering, idempotency, rebuild, reconciliation, move, cycle, archive/restore, validation, search/filter, metadata event;
- database: fresh create, v1→v2 migration, foreign keys, indexes, atomic create, reopen persistence, duplicate ids/keys, append-only triggers;
- widget: empty catalog, card, add/validation/confirmation, large mode, 200% text, semantics, `needs_reconciliation`;
- integration: clean onboarding → location tree → batch 18 → take 2 → return 1 → spoil 1 → remaining 16 → four events → repository restart → same data/history.
- QR unit/repository: opaque payload parser/version, Luhn checksum, stable batch label, unlinked→linked transaction, revoked/replaced resolution, and separation from inventory events.

## Последний фактический прогон — 2026-07-19

| Gate | Результат |
|---|---|
| `flutter pub get` | PASS |
| `dart format` | PASS |
| `flutter analyze` | PASS, 0 issues |
| `flutter test` | PASS, 27 tests |
| integration, iPhone 17 simulator / iOS 26.5 | PASS |
| integration, Pixel 7 emulator / Android 35 | PASS |
| `flutter build apk --debug` | PASS |
| `flutter build ios --simulator --debug` | PASS |
| physical iOS build/run | NOT_RUN |
| physical Android build/run | NOT_RUN |
| manual VoiceOver/TalkBack | NOT_RUN |

## R2 checkpoint

| Gate | Результат |
|---|---|
| `flutter pub get` | PASS |
| `dart format --set-exit-if-changed .` | PASS |
| `flutter analyze` | PASS, 0 issues |
| `flutter test` | PASS, 33 tests |
| R2 integration on physical iPhone | NOT_RUN: `devicectl` launched the app stopped under LLDB and did not return a test result; process was stopped without changing app data |
| Android debug artifact | updated `build/app/outputs/flutter-apk/app-debug.apk` at 20:36; terminal did not return a final exit status |
| iOS simulator artifact | updated `build/ios/iphonesimulator/Runner.app` at 20:36; terminal did not return a final exit status |
| camera permission / flashlight / paper scan / PDF preview-share | NOT_RUN |
