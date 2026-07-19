# ADR 0011: локальные PDF-этикетки

Выбраны `pdf 3.13.0` и `printing 5.15.0`, Apache-2.0. `pdf` формирует векторный QR на A4 локально, `printing` показывает системный preview, печать и share sheet на iOS/Android. Реализованы один крупный label, 2×4 medium и 3×8 small grid, а также выбранные партии и свободные labels. Размер QR проверяется UX-ограничением 25 мм; в этикетку не попадает текущий остаток.

Для одинаковой кириллицы на iOS/Android в PDF встраиваются локальные Roboto Regular/Bold assets, а не системный font и не сетевой font provider.
