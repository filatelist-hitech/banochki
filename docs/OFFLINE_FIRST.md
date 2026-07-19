# Offline-first в R1

## Локальный write path

1. UI вызывает `AppController`.
2. Controller вызывает только `InventoryRepository`.
3. SQLite transaction проверяет invariant/idempotency.
4. В одной транзакции добавляется event, обновляется projection и связанная metadata.
5. Controller повторно читает локальный snapshot; сеть не участвует.

Создание партии атомарно записывает batch, `BATCH_CREATED` и projection. Повтор одного idempotency key возвращает существующий эффект.

## Перезапуск

Production database хранится как `banochki.sqlite` в app-private databases directory. Bootstrap открывает её через versioned migrations до отображения основного интерфейса. Integration test закрывает repository, создаёт новый database/repository instance и подтверждает сохранение партии, остатка 16 и четырёх событий.

## Расхождение остатка

Локальный UI предупреждает до события, которое делает computed quantity отрицательным. Если физическое действие подтверждено, событие сохраняется, computed quantity остаётся отрицательным, UI показывает `0 · Нужно уточнить`. Исправление — только новым `INVENTORY_RECONCILED`.

## Сеть

В runtime dependencies отсутствуют HTTP/Supabase/Firebase SDK. R1 не открывает сокеты и не содержит фоновой синхронизации. Будущий R3 должен использовать отдельный adapter/queue за repository contract.

## Защита локальных данных

R1 использует app-private SQLite storage и platform sandbox. SQLCipher/key lifecycle не реализованы и не изображаются готовыми; решение отложено ADR 0002 с обязательной migration strategy до cloud identity.
