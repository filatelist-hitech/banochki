# Архитектура R1

## Граница этапа

R2 расширяет offline vertical slice QR-этикетками. Supabase, sync queue, voice и recipes по-прежнему не реализованы.

## Направление зависимостей

```text
Flutter presentation
        ↓
Riverpod AppController
        ↓
InventoryRepository (domain contract)
        ↓
SqliteInventoryRepository
        ↓
AppDatabase + versioned migrations
```

Presentation не выполняет SQL. Domain models не импортируют Flutter или SQLite. `AppClock` и `IdGenerator` инъецируются для детерминированных тестов.

## Модули

- `app/` — bootstrap, обработка loading/error/onboarding, единый application state;
- `core/database/` — открытие SQLite и последовательные миграции;
- `core/ui/` — semantic colors, typography through ThemeData, spacing, radii, touch targets и компоненты;
- `features/inventory/domain/` — сущности, статусы, query и repository interface;
- `features/inventory/data/` — единственная SQLite implementation;
- `features/qr/` — versioned payload/parser, QR presentation и scanner state machine; persistence остаётся за repository boundary;
- `features/*/presentation/` — onboarding, home, catalog, details, history, locations, settings и large mode.

## State management

Riverpod 3 используется как единственная система состояния. `AppController` выполняет команды repository и после атомарной записи заново читает snapshot/catalog. Локальная БД остаётся source of truth; Riverpod не становится второй базой.

## Адаптивность

- до 700 logical px — нижняя navigation bar;
- от 700 px — navigation rail;
- каталог от 900 px использует две колонки;
- крупный режим увеличивает touch targets и высоту карточек, но использует те же entities/repository.

## Расширение после R1

Будущая синхронизация должна подключаться за repository boundary и принимать локальный event log как исходящий поток. Нельзя добавлять прямые сетевые вызовы в UI или превращать server projection в единственный источник остатка.

QR token и short code уже содержат device/member provenance и стабильны для R3; они не зависят от часов устройства и не попадают в inventory analytics/logging.
