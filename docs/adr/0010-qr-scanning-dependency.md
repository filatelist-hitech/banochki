# ADR 0010: сканирование QR

Выбран `mobile_scanner 7.3.0`, BSD-3-Clause. На Android он использует CameraX/ML Kit, на iOS — AVFoundation/Apple Vision; поддерживает QR и controller lifecycle. Проект уже имеет Android compileSdk 36 и iOS 13+, что превышает заявленный package minimum Android compileSdk 34.

Сканер ограничен QR, останавливает камеру после первого frame и разрешает повтор только явным действием. Кадры не сохраняются и не отправляются.
