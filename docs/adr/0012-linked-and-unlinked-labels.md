# ADR 0012: связанные и свободные этикетки

`qr_codes` допускает `batch`, `storage_location`, `unlinked`. Свободная этикетка не получает цель автоматически: `LinkQrToBatch`/`LinkQrToStorageLocation` выполняются транзакционно и оставляют `QR_LINKED` в append-only `qr_events`. Отзыв и перевыпуск сохраняют запись с состояниями `revoked`/`replaced`.
