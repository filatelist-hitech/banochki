# R3 Family sync

## Контракт

```text
UI -> application/repository -> SQLite event + projection + sync_outbox -> Supabase RPC
                                                               ^               |
                                                               +-- pull cursor -+
```

Local write не ждёт сеть. `sync_outbox` имеет состояния `pending`, `sending`, `acknowledged`, `retry_wait`, `blocked`, `failed_permanently`; retry — exponential backoff с jitter. Cursor продвигается только после одной SQLite transaction, применившей весь page. Realtime запускает pull, но пропущенный сигнал компенсирует ручной/periodic pull.

## Auth, семья и invite

`auth.users` — account; `family_members` — доменный человек и может не иметь account. Email OTP/magic link — базовый путь. Anonymous auth возможен до invite claim, но RLS не даёт ему семейных строк. Raw invite token/short code показывается лишь при создании; сервер получает SHA-256 hash. `accept_family_invite` lock-ит invite, проверяет TTL/revocation/max uses и claim-ит предварительно заведённого member или создаёт нового. QR invite отдельный от QR партии.

| Role | read | batches/events | locations | invites | roles/remove |
|---|---|---|---|---|---|
| owner | yes | yes | yes | yes | yes |
| admin | yes | yes | yes | yes | no owner removal |
| member | yes | yes | no metadata admin | no | no |
| viewer | yes | no | no | no | no |

RLS всегда проверяет active membership на сервере. Removed member теряет последующие reads/writes; Flutter не содержит service-role key.

## Фото и conflicts

Private bucket `batch-photos`; разрешён только путь `families/<family_uuid>/batches/<batch_uuid>/<photo_uuid>.(jpg|png|webp)`, максимум 10 MiB. Upload queue независима от сохранения партии; app отправляет только подтверждённо выбранное фото, хранит checksum/local thumbnail и повторяет временные ошибки.

Inventory events объединяются по immutable ID/idempotency key; отрицательный остаток остаётся видимым и требует reconciliation. Batch metadata использует base version + three-way field merge: независимые поля объединяются, один и тот же field создаёт `sync_conflicts`. Archive/tombstone сильнее устаревшего metadata edit, QR public token не меняется.

## Local Supabase

```bash
cp .env.example .env
supabase start
supabase db reset       # только локальная dev база
supabase test db
supabase db diff --schema public
```

`supabase/migrations` — единственный schema source. `.env` не коммитится; seed не содержит PII. Для production reset запрещён: `db reset --linked` разрушителен.

## Проверочная матрица

Database/RLS pgTAP: outsider, viewer, member, admin, owner, removed member, expired invite; для каждого — select/insert/update/archive/invite/photo и family-id substitution. Два устройства: A offline creates 18 and takes 2; B offline takes 1; после push/pull оба имеют три events, quantity 15 и равные projection. В тестах также: duplicate push, failed pull transaction, pagination, lost Realtime signal, expired/repeated invite, short-code collision, revoked device/membership и photo retry.

## Ограничения R3 implementation

Server migration и local outbox protocol готовы; UI onboarding/invite, actual Supabase transport binding и physical two-device run остаются следующими implementation slices. Поэтому R3 нельзя помечать DONE до `supabase db reset/test db`, Flutter integration test с двумя клиентами и security matrix на локальном stack.
