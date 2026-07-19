# ADR 0007: Текущая execution boundary — R1

- Статус: Accepted
- Дата: 2026-07-19

## Контекст

Исходный OMX plan описывает весь Release 1 с Supabase, QR, media и sync. Текущий пользовательский порядок этапов отделяет local foundation (R1) от QR (R2), family sync (R3), voice (R4) и recipes/planning (R5).

Старая event vocabulary использовала `BATCH_EDITED`; контракт R1 требует `BATCH_METADATA_UPDATED` и `BATCH_RESTORED`.

## Решение

- текущий active/done slice ограничен R1;
- canonical local event names: `BATCH_METADATA_UPDATED` и `BATCH_RESTORED`;
- R2–R5 не получают UI stubs и fake implementations;
- full MVP plan сохраняется, но его status section явно показывает завершение только R1.

## Последствия

R1 можно проверять и использовать без backend. Следующая допустимая feature boundary — R2 QR workflow; архитектурные заготовки не считаются его реализацией.
