# Banochki mobile

Flutter-приложение этапов **R1: Local foundation** и **R2: QR workflow**.

- [Описание проекта и быстрый старт](../../README.md)
- [Подробный гайд по запуску](../../docs/GETTING_STARTED.md)
- [Архитектура](../../docs/ARCHITECTURE.md)
- [Тестирование](../../docs/TESTING.md)

Core flow полностью локальный:

```text
Flutter UI → Riverpod application controller → Repository → SQLite
```

R2 добавляет локальные QR payload/short code, сканер, PDF preview/print/share и свободные этикетки. Дополнительно реализованы локальные фото партии: app-private copy файла, листаемая галерея и превью в каталоге. Количество хранится вместе с единицей партии (`шт.`, `мл`, `г` или пользовательской). Сетевых SDK и runtime-зависимости от backend в R1/R2 нет.
