# ADR 0003: Append-only event log и rebuildable projections

- Статус: Accepted
- Дата: 2026-07-19

## Решение

`inventory_events` — canonical источник остатка и текущего места. `inventory_projections` — только read model. SQLite triggers запрещают update/delete событий. Каждая mutation добавляет UUID event и обновляет projection в одной transaction.

Projection reducer проигрывает события в порядке `created_at, event_id`. Полный rebuild удаляет только projections, повторяет журнал и синхронизирует denormalized current location в batch metadata.

## Idempotency

Область уникальности: `(family_id, device_id, idempotency_key)`. Повтор возвращает существующее событие и не применяет delta второй раз.

## Последствия

Историю можно проверять и восстанавливать после corruption projection. Цена — metadata/event schema должна версионироваться, а прошлые события нельзя «быстро поправить» SQL update.
