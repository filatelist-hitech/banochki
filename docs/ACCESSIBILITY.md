# Accessibility R1/R2

Baseline: WCAG 2.2 AA + platform semantics.

## Реализовано

- обычные touch targets не меньше 52 dp, крупные — 64 dp;
- крупный home содержит пять явных подписанных действий;
- крупное создание партии идёт вопросами «Что? → Сколько? → Где? → Всё верно?»;
- core actions не требуют swipe, long press, drag-and-drop или icon-only knowledge;
- карточка партии объявляет название, остаток, полный путь и статус одной semantics-фразой;
- breadcrumb, quantity и status имеют текстовые semantics;
- цвет не является единственным носителем статуса;
- system text scaling не ограничивается;
- light/dark/system themes используют semantic tokens;
- adaptive navigation поддерживает телефон и планшет;
- каждое изменение получает крупное текстовое подтверждение и явное исправление.
- QR scanner имеет крупную рамку, подписанные «Фонарик», «Ввести номер» и «Закрыть»; короткий номер — полноценный путь без камеры.
- QR label имеет text alternative с коротким номером, чёрно-белый контраст и quiet zone; PDF не печатает остаток.

## Автоматически проверено

- BatchCard при `TextScaler.linear(2)` без framework exception;
- semantics label карточки;
- размер large action ≥ 56 dp;
- Flutter guidelines для Android tap targets, labeled targets и text contrast на large home;
- `needs_reconciliation` отображается текстом без отрицательного display quantity;
- large home и confirmation actions присутствуют.

## Не проверено физически

- VoiceOver walkthrough: `NOT_RUN`;
- TalkBack walkthrough: `NOT_RUN`;
- Switch Access / external keyboard: `NOT_RUN`;
- пять целевых пользователей и ≥85% task success: `NOT_RUN`;
- инструментальный scanner контраста всей матрицы экранов/состояний: `NOT_RUN` (large home automated guideline — PASS).
- physical iPhone QR scan и ручной short-code search: `PASS` (пользовательская проверка, 2026-07-19).
- flashlight, paper scan, PDF system preview/share и VoiceOver/TalkBack: `NOT_RUN` до отдельной ручной matrix.

Эти пункты нельзя считать PASS по результатам widget tests; они остаются release evidence перед beta.
