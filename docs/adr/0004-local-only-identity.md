# ADR 0004: Локальная identity для R1

- Статус: Accepted for R1
- Дата: 2026-07-19

## Решение

Первый запуск создаёт `LocalProfile`, `Family`, `FamilyMember` и `DeviceIdentity` с client UUID. Телефон, email, auth token и server account не нужны. Один local profile является actor текущего устройства.

## Граница

R1 не симулирует invites, roles, remote membership или sync status. Таблицы и UUID позволяют позднее связать локальную identity с R3 account, но migration/ownership conflict policy ещё не реализованы.

## Последствия

Core flow работает полностью offline. Потеря устройства пока означает отсутствие cloud recovery; README и UI не обещают обратного.
