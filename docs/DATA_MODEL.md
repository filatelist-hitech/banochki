# Модель данных R1

SQLite schema version: **3**.

## Миграции

1. `v1 core schema` — profiles, families, members, device identity, locations, batches, batch photos, inventory events, projections, settings и append-only triggers.
2. `v2 indexes and metadata` — scoped idempotency unique index, event ordering, catalog/location/tree indexes и `schema_metadata`.
3. `v3 QR labels` — `qr_codes`, append-only `qr_events`, opaque token/short-code unique indexes и target lookup.

Миграции выполняются последовательно внутри lifecycle `openDatabase`; `PRAGMA foreign_keys = ON` включается до create/upgrade.

## Таблицы

| Таблица | Назначение |
|---|---|
| `local_profiles` | локальный профиль человека |
| `families` | локальная семейная граница |
| `family_members` | первый и debug-участники |
| `device_identities` | стабильный UUID устройства и последовательность idempotency keys |
| `storage_locations` | adjacency-list дерево мест |
| `batches` | метаданные партии и initial quantity, но не remaining |
| `inventory_events` | неизменяемый журнал |
| `inventory_projections` | пересобираемый read model остатка/места/reconciliation |
| `batch_photos` | контракт локального фото; UI R1 показывает заглушку |
| `app_settings` | theme, large mode, low-stock threshold, seed flag |
| `schema_metadata` | явная версия схемы |
| `qr_codes` | stable public token, short code, target, lifecycle и sync-ready actor/device fields |
| `qr_events` | append-only техническая история QR без token |

## QR R2

QR payload: `banochki://qr/v1/<base64url-random-token>`. В нём нет PII или данных партии. `short_code` имеет вид `XXXXXX-C`, где `C` — Luhn checksum; `(family_id, short_code)` и `public_token` уникальны. Linked targets проверяются в одной SQLite transaction; QR не меняет остаток и не добавляет inventory event.

## События R1

`BATCH_CREATED`, `JARS_TAKEN`, `JARS_RETURNED`, `JARS_SPOILED`, `BATCH_MOVED`, `BATCH_METADATA_UPDATED`, `INVENTORY_RECONCILED`, `NOTE_ADDED`, `BATCH_ARCHIVED`, `BATCH_RESTORED`.

`inventory_events` защищён SQLite triggers от `UPDATE` и `DELETE`. Уникальны `event_id` и `(family_id, device_id, idempotency_key)`.

## Projection reducer

- `computed_quantity = SUM(quantity_delta)` в детерминированном порядке `created_at, event_id`;
- `display_quantity = max(computed_quantity, 0)` вычисляется только для понятного UI;
- отрицательное computed-значение сохраняется и включает `needs_reconciliation`;
- только `INVENTORY_RECONCILED` очищает reconciliation flag;
- текущее место получается проигрыванием `BATCH_CREATED` и `BATCH_MOVED`;
- полный rebuild удаляет только projections и повторно проигрывает все события.

## Derived statuses

Приоритет правил:

1. `archived`, если партия архивирована;
2. `needs_reconciliation`, если есть неуточнённое расхождение;
3. `spoiled`, если остаток 0 и последнее уменьшающее событие — порча;
4. `finished`, если остаток 0;
5. `needs_check`, если наступила `check_at` и остаток положительный;
6. `last_one_or_two`, если осталось 1–2;
7. `running_low`, если осталось не больше настраиваемого порога (по умолчанию 4);
8. `many` во всех остальных активных случаях.
