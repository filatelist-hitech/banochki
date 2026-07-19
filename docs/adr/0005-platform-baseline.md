# ADR 0005: Минимальные версии платформ

- Статус: Accepted
- Дата: 2026-07-19

## Наблюдаемая toolchain

- Flutter 3.44.0 stable, Dart 3.12.0;
- Xcode 26.6, CocoaPods 1.16.2;
- Android SDK/compile/target 36, JDK 17;
- локальный Flutter default Android minSdk — 24;
- generated Xcode project deployment target — iOS 13.0.

## Решение

Зафиксировать Android API 24 / compile+target 36 и iOS 13.0. Эти значения совместимы с установленной toolchain и `sqflite`.

## Проверка

Debug build и integration test прошли на iPhone 17 simulator (iOS 26.5) и Pixel 7 emulator (Android 35). Нижние границы iOS 13/API 24 не запускались на реальных reference devices и остаются compatibility risk до beta matrix.
