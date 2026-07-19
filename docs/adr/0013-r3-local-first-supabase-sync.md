# ADR 0013: R3 local-first sync через Supabase

Дата: 2026-07-19. Статус: Accepted.

UI читает только SQLite. Команда сначала атомарно записывает local event/projection и outbox; Supabase получает batch позже. `supabase_flutter ^2.16.0` выбран как текущий stable (Dart >=3.9, проект использует Dart 3.12). Auth: email OTP/magic link; anonymous session допустима только до claim invite и не даёт family access. Realtime/Postgres Changes — wake-up hint: после сигнала всегда `pull_changes(cursor)`.

Серверный cursor — `sync_changes.server_sequence` (identity bigint), а не `updated_at`: это не ломается от clock skew. Inventory остаётся append-only, receipt привязан к `operation_id`, повторный push возвращает уже выданный sequence. Metadata применяет optimistic version и three-way field merge; конфликт одного поля сохраняется, а не перетирается.

Отклонено: cloud-first CRUD, client-side `family_id` filtering, public photo bucket, service-role в приложении, бессрочные invite bearer tokens и Realtime как единственный transport.
