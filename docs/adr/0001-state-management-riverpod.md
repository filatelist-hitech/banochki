# ADR 0001: Riverpod как единая система состояния

- Статус: Accepted
- Дата: 2026-07-19
- Этап: R1

## Контекст

UI должен работать с асинхронным локальным repository, отображать bootstrap/error/data и не создавать вторую mutable database в памяти.

## Решение

Использовать `flutter_riverpod` 3.x. Один `AppController` выполняет application commands и после commit перечитывает snapshot/catalog. Repository передаётся provider-ом и переопределяется в tests.

## Правила

- не добавлять Bloc, Provider, MobX или parallel state store;
- UI не читает SQLite напрямую;
- canonical state находится в SQLite, Riverpod хранит только актуальный view snapshot/query;
- domain не импортирует Riverpod.

## Последствия

Плюсы: единая DI/state boundary, тестируемые overrides, явные loading/error states. Минус: текущий controller перечитывает snapshot после каждой mutation; при росте данных понадобится реактивный/инкрементальный read layer без изменения domain contract.
