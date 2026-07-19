# ADR 0007: Execution boundary R1/R2

- Статус: Accepted
- Дата: 2026-07-19

## Контекст

Исходный OMX plan описывает весь Release 1 с Supabase, QR, media и sync. Текущий пользовательский порядок этапов отделяет local foundation (R1) от QR (R2), family sync (R3), voice (R4) и recipes/planning (R5).

Старая event vocabulary использовала `BATCH_EDITED`; контракт R1 требует `BATCH_METADATA_UPDATED` и `BATCH_RESTORED`.

## Решение

- R1 завершён как local foundation;
- canonical local event names: `BATCH_METADATA_UPDATED` и `BATCH_RESTORED`;
- R2 завершён как local QR workflow без backend/sync;
- R3–R5 не получают UI stubs и fake implementations;
- full MVP plan сохраняется, а status section показывает завершение R1/R2 и beta evidence, которая ещё не собрана.

## Последствия

R1/R2 можно проверять и использовать без backend. Следующая допустимая feature boundary — R3 family sync; QR contract и локальная event model остаются source of truth.
