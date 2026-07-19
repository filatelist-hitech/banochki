# ADR 0002: SQLite через sqflite

- Статус: Accepted for R1
- Дата: 2026-07-19

## Контекст

R1 требует зрелый mobile SQLite layer, migrations, foreign keys, indexes, transactions и reopen tests. Domain не должен зависеть от библиотеки хранения.

## Решение

Использовать `sqflite` 2.4.x в runtime и `sqflite_common_ffi` только в tests. SQL централизован в `core/database` и data repository. Schema version — 2.

## Шифрование

Текущая фиксированная спецификация R1 требует SQLite, но не выбирает SQLCipher/key lifecycle. Старый full-MVP plan предполагал encrypted SQLite. Минимальное обратимое решение: хранить R1 database в app-private sandbox, не заявлять encryption и не вводить непроверенный encryption plugin. Перед R3 обязателен отдельный security spike: SQLCipher compatibility, Keychain/Keystore lifecycle, backup/restore и migration существующих R1 databases.

## Последствия

Плюсы: поддерживаемый mobile plugin, простые raw migrations, реальные FFI database tests. Минусы: ручной mapping/SQL и отсутствие field/database encryption поверх OS protection в R1.
