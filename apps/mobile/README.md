# Banochki mobile

Flutter-приложение этапа **R1: Local foundation**.

- [Описание проекта и быстрый старт](../../README.md)
- [Подробный гайд по запуску](../../docs/GETTING_STARTED.md)
- [Архитектура](../../docs/ARCHITECTURE.md)
- [Тестирование](../../docs/TESTING.md)

Core flow полностью локальный:

```text
Flutter UI → Riverpod application controller → Repository → SQLite
```

Сетевых SDK и runtime-зависимости от backend в R1 нет.
