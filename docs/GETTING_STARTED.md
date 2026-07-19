# Запуск проекта «Баночки»

Этот гайд проводит от чистого checkout до работающего приложения на iOS Simulator или Android Emulator. R1 полностью локальный: backend, API-ключи, `.env` и интернет после установки зависимостей не нужны.

## 1. Требования

Общая toolchain:

- Flutter 3.44.0 или совместимая более новая stable-версия;
- Dart 3.12.0 или версия из установленного Flutter SDK;
- Git;
- свободное место для Flutter artifacts и одного симулятора/эмулятора.

Проверьте окружение:

```bash
flutter --version
dart --version
flutter doctor -v
```

Исправьте ошибки, которые `flutter doctor` отмечает для нужной платформы. Предупреждение о неподготовленной платформе можно игнорировать, если вы на ней не запускаетесь: например, отсутствие Xcode не мешает Android-разработке.

### iOS

Нужны:

- macOS;
- Xcode с установленной iOS Simulator runtime;
- CocoaPods, если его требует текущая Flutter/Xcode toolchain.

Минимальная версия приложения — iOS 13.0.

### Android

Нужны:

- Android Studio или отдельно установленный Android SDK;
- Android SDK Platform и Build Tools;
- эмулятор с системным образом либо физическое устройство с USB debugging.

Минимальная версия приложения — Android API 24 (Android 7.0).

## 2. Установка зависимостей

Из корня репозитория:

```bash
cd apps/mobile
flutter pub get
```

В R1 нет ручной code generation и нет конфигурации backend. После успешного `pub get` проект готов к запуску.

## 3. Запуск на iOS Simulator

Откройте Simulator:

```bash
open -a Simulator
```

Проверьте, что Flutter видит устройство:

```bash
flutter devices
```

Запустите приложение, подставив идентификатор симулятора из предыдущей команды:

```bash
flutter run -d <ios-simulator-id>
```

Если Simulator единственный доступный target:

```bash
flutter run
```

Сборка без запуска:

```bash
flutter build ios --simulator --debug
```

Результат появится в `build/ios/iphonesimulator/Runner.app`.

## 4. Запуск на Android Emulator

Посмотрите доступные эмуляторы:

```bash
flutter emulators
```

Запустите выбранный:

```bash
flutter emulators --launch <emulator-id>
```

Дождитесь загрузки Android, затем:

```bash
flutter devices
flutter run -d <android-device-id>
```

Debug APK без запуска:

```bash
flutter build apk --debug
```

Результат появится в `build/app/outputs/flutter-apk/app-debug.apk`.

## 5. Запуск на физическом устройстве

### iPhone или iPad

1. Подключите устройство к Mac.
2. Подтвердите доверие компьютеру на устройстве.
3. Откройте `apps/mobile/ios/Runner.xcworkspace` в Xcode и настройте Signing Team для локальной разработки.
4. Убедитесь, что устройство видно в `flutter devices`.
5. Выполните `flutter run -d <device-id>`.

### Android

1. Включите Developer options и USB debugging.
2. Подключите устройство и подтвердите RSA fingerprint.
3. Убедитесь, что оно видно в `flutter devices`.
4. Выполните `flutter run -d <device-id>`.

Физические устройства особенно важны для ручной проверки размеров целей касания, VoiceOver и TalkBack.

## 6. Первый пользовательский сценарий

После запуска приложение откроет onboarding.

### Чистый старт

1. Введите название семьи и имя участника.
2. Создайте первое место, например `Дом`.
3. Добавьте дочерние места: `Кладовая → Стеллаж → Полка 1`.
4. Откройте каталог и создайте партию.
5. На карточке партии используйте действия «Взял», «Вернул» или «Испорчено».
6. Откройте историю и убедитесь, что каждое действие записано отдельным событием.

### Готовый debug-пример

В debug-сборке нажмите **«Открыть debug-пример»** на onboarding. Будут созданы:

- семья `Семья Филателиста`;
- участник;
- дерево мест;
- демонстрационная партия;
- события, показывающие изменение остатка.

Добавить пример после onboarding можно через **Настройки → Добавить debug-данные**. Операция безопасна для повторного запуска: существующие демонстрационные записи не размножаются бесконечно.

В release-сборке debug seed недоступен.

## 7. Проверки перед изменениями и коммитом

Из `apps/mobile`:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Сквозной R1 flow на реальном target:

```bash
flutter test integration_test/r1_local_flow_test.dart -d <device-id>
```

Тест создаёт данные, выполняет операции с партией и проверяет сохранение состояния в локальной базе.

Полезный полный цикл для обеих платформ:

```bash
flutter build apk --debug
flutter build ios --simulator --debug
```

Команда iOS работает только на macOS с настроенным Xcode.

## 8. Где хранятся данные

Приложение использует SQLite через `sqflite`. Файл базы находится в app-private storage выбранного устройства или симулятора. Пользовательские действия пишутся как append-only события, а текущие остатки и карточки восстанавливаются как projections.

Важно:

> Удаление приложения или очистка его storage удаляет локальную базу. В R1 нет облачной копии и восстановления с другого устройства.

Для проверки на чистой базе безопаснее создать новый simulator/emulator или удалить приложение только после осознанного подтверждения, что локальные данные не нужны.

## 9. Частые проблемы

### `flutter devices` не показывает устройство

- Запустите simulator/emulator и дождитесь полной загрузки.
- Выполните `flutter doctor -v` и исправьте ошибки нужной платформы.
- Для Android переподключите USB и подтвердите RSA fingerprint.
- Для iOS подтвердите доверие компьютеру и проверьте устройство в Xcode.

### iOS не собирается после обновления зависимостей

Из `apps/mobile`:

```bash
flutter clean
flutter pub get
cd ios
pod install
cd ..
flutter run
```

`flutter clean` удаляет только сгенерированные build artifacts, не локальную базу уже установленного приложения.

### Android сообщает о лицензиях SDK

```bash
flutter doctor --android-licenses
flutter doctor -v
```

Примите лицензии и повторите запуск.

### Изменения интерфейса не применились

Во время `flutter run` нажмите `r` для hot reload. Для изменений инициализации, миграций или native-конфигурации используйте `R` (hot restart) либо перезапустите команду.

### Нужно проверить миграцию, не теряя основную базу

Не очищайте storage рабочего устройства. Используйте отдельный simulator/emulator и тесты из `test/core/database` — так космический слизень данных останется в своей банке.

## 10. Куда идти дальше

- Архитектура и зависимости слоёв: [`ARCHITECTURE.md`](ARCHITECTURE.md)
- SQLite-схема и события: [`DATA_MODEL.md`](DATA_MODEL.md)
- Offline-first гарантии: [`OFFLINE_FIRST.md`](OFFLINE_FIRST.md)
- Доступность и крупный режим: [`ACCESSIBILITY.md`](ACCESSIBILITY.md)
- Матрица проверок: [`TESTING.md`](TESTING.md)
- Архитектурные решения: [`adr/`](adr/)
