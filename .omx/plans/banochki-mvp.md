# План реализации MVP «Баночки»

- Статус: Active; R1 Local foundation — implemented and verified
- Дата: 2026-07-19
- Основание: `PRODUCT_SPEC.md`, `DESIGN.md`
- Режим планирования: direct; исходный бриф подробный, кодовая база отсутствует.
- Граница: план заканчивается закрытой beta Release 1 «Вижу и беру»; post-MVP не реализуется, кроме подготовленных расширяемых контрактов.

## Current execution state

- Текущий этап: **R2: QR workflow**.
- Статус этапа: **IN_PROGRESS — local QR schema, resolver, scanner UI and single-label PDF implemented; device/print matrix pending**.
- Evidence date: 2026-07-19.
- Следующий допустимый этап: завершить R2 device/print matrix и расширить label-sheet templates; R3 sync не начинать до закрытия этих evidence.

Текущий пользовательский stage contract имеет приоритет над прежней группировкой full MVP: QR относится к R2, Supabase/family sync — к R3, voice — к R4, recipes/season planning — к R5. Эти функции не реализованы и не показаны как заглушки в R1.

| R1 packet | Фактический статус | Evidence |
|---|---|---|
| Checkpoint/toolchain | DONE | Flutter 3.44, Dart 3.12, Android SDK 36, Xcode 26.6; исходно только docs |
| Flutter bootstrap | DONE | `apps/mobile`, iOS 13+, Android API 24+ |
| Local identity | DONE | LocalProfile, Family, first FamilyMember, DeviceIdentity |
| SQLite/migrations | DONE | schema v1 core + v2 indexes/metadata, FK, transactions, reopen tests |
| Events/projections | DONE | append-only triggers, idempotency, full rebuild, reconciliation |
| Locations | DONE | create/edit/nesting/move/cycle guard/archive guard/full path |
| Batch/catalog/history | DONE | create/edit/archive/search/filter/sort/details/actions/history |
| Large mode | DONE | large home, step-by-step create, large confirmation, shared repository |
| Automated QA | DONE | analyze 0 issues, 27 tests, iOS+Android integration PASS |
| Debug builds | DONE | Android APK and iOS Simulator app |
| Physical accessibility evidence | NOT_RUN | VoiceOver/TalkBack/target-user matrix remains beta evidence |

### R1 architectural decisions

- State: Riverpod only — `docs/adr/0001-state-management-riverpod.md`.
- Persistence: sqflite, app-private unencrypted R1 DB — `docs/adr/0002-sqlite-sqflite.md`.
- Event log/projections — `docs/adr/0003-event-log-and-projections.md`.
- Local identity — `docs/adr/0004-local-only-identity.md`.
- Platform baseline — `docs/adr/0005-platform-baseline.md`.
- Reconciliation — `docs/adr/0006-reconciliation.md`.
- Scope/event vocabulary — `docs/adr/0007-r1-scope-contract.md`.

## Requirements Summary

### Результат

Поставить проверенный Flutter MVP семейного цифрового погреба, в котором семья офлайн создаёт партии, видит остаток/место, записывает движения append-only событиями, сканирует QR и синхронизирует данные через Supabase без потери операций. Крупный режим входит в definition of done, а не является последующей темой.

### Источники требований

- Позиционирование и non-goals: `PRODUCT_SPEC.md:10`, `PRODUCT_SPEC.md:42`.
- North Star, guardrails и beta targets: `PRODUCT_SPEC.md:51`.
- Domain model и роли: `PRODUCT_SPEC.md:152`.
- Event invariants: `PRODUCT_SPEC.md:206`.
- Offline write/push/pull/media strategy: `PRODUCT_SPEC.md:255`.
- Conflict policy: `PRODUCT_SPEC.md:309`.
- Screen map, large mode и wireflows: `PRODUCT_SPEC.md:332`, `PRODUCT_SPEC.md:387`, `PRODUCT_SPEC.md:408`.
- P0/P1 boundary и release gates: `PRODUCT_SPEC.md:530`, `PRODUCT_SPEC.md:580`.
- Detailed acceptance criteria: `PRODUCT_SPEC.md:675`.
- SQL/API drafts: `PRODUCT_SPEC.md:858`, `PRODUCT_SPEC.md:1179`.
- UI decision contract: `DESIGN.md:3`, `DESIGN.md:62`, `DESIGN.md:97`, `DESIGN.md:180`, `DESIGN.md:264`.

### MVP scope

- Flutter iOS/Android app with phone/tablet adaptation.
- Local encrypted SQLite repository and projections.
- Batch creation/edit/archive, photos, locations, catalog/search/filter.
- Inventory events and history, including undo/reconciliation.
- Family bootstrap/invite, four role presets and capability checks.
- Idempotent push/pull/snapshot sync; Realtime only as wake-up hint.
- QR resolve/scan/manual code/link and revocation.
- Large mode, screen-reader semantics, large-text layouts.
- Minimal JSON export, observability and data-loss/security test suites.

### Explicitly out of scope

- Family requests, recipes, analytics, push, A4 printing and CV except contract placeholders.
- Public social/recipe surfaces.
- Safety classification.
- Per-jar identity.
- AI changing canonical data.
- Production deployment, store publication, push or external messages without separate approval.

### Assumptions to validate before build freeze

- Target geography/legal regime, account recovery, relative access breadth, unit dictionary, minimum OS versions and reference devices are unresolved in `DESIGN.md:295`.
- Voice in Release 1 defaults to OS dictation/assisted draft unless research proves app-level parsing critical.
- Flutter package choices for SQLite, encryption, routing and state management require a short ADR after compatibility spikes; product architecture stays repository-driven regardless of library.

## Acceptance Criteria

### Product

- A new family reaches the first saved batch in p50 ≤ 3 minutes in moderated beta onboarding.
- A user with an opened batch completes «Взял 1» in p50 ≤ 5 seconds and no more than two explicit taps.
- Physical reconciliation matches the computed quantity in ≥ 90% of checked batches after four weeks.
- No UI, notification or voice string claims that food is safe.
- The app remains fully usable for core local flows with airplane mode enabled for 24 hours.

### Data integrity and sync

- Repository transaction atomically persists operation, local event and projection before UI success.
- Replaying an identical operation 10 times produces one domain effect.
- Killing the app after local commit, during upload, after server commit/before response and during pull loses zero operations.
- Projection rebuild from events matches stored projection for every generated test history.
- Two devices converge to identical event ids, quantity, current location and entity versions after sync.
- Concurrent offline underflow preserves both physical actions and yields `needs_reconciliation`, never a silently dropped event.

### Security/privacy

- Automated RLS tests prove family A cannot select or mutate any resource of family B under every role.
- QR payload contains no family id, title, location or other PII and requires active membership to resolve.
- Invite codes are high-entropy, hashed, rate-limited, expiring and revokeable.
- Client credentials cannot directly update/delete accepted events or write projections.
- EXIF location is stripped before media upload; telemetry contains no user content or QR/invite secrets.
- Member revocation prevents new server reads/writes and locks cached family content according to retention policy.

### UX/accessibility

- All large-mode core actions have labeled targets ≥ 56×56 dp.
- Create/view/take/find-location flows need no swipe, drag, long press or icon-only action.
- Layout remains functional at 200% text scale without horizontal scrolling in core flows.
- Flutter accessibility guideline tests cover contrast, target size and labels; manual VoiceOver/TalkBack matrix passes.
- At least five target users complete four core tasks; ≥ 85% task success without moderator help.
- Offline state reads «На устройстве» and only actionable failures use «Нужно внимание».

### Performance/operations

- Local action feedback p95 < 100 ms on the chosen low-tier reference device.
- A warmed catalog of 5,000 batches opens/filters p95 < 300 ms.
- Sync age, retries, projection mismatches, crashes and RLS denies are observable without product content.
- Crash-free sessions and ANR thresholds are set before beta and block expansion if violated.

## Proposed repository structure

```text
apps/mobile/
  lib/
    app/
    core/database/
    core/sync/
    core/security/
    design_system/
    features/onboarding/
    features/batches/
    features/inventory/
    features/locations/
    features/qr/
    features/history/
    features/settings/
  test/
  integration_test/
  assets/
packages/domain/
  lib/
  test/
supabase/
  config.toml
  migrations/
  functions/
  tests/database/
docs/
  adr/
  threat-model.md
  privacy-retention.md
  qa/
```

Структура — стартовое решение, не разрешение плодить слои. Если Flutter bootstrap показывает, что отдельный `packages/domain` создаёт лишнее трение, domain остаётся внутри `apps/mobile/lib/domain/` и это фиксируется ADR.

## Implementation Steps

### 0. Product validation and build freeze

**Deliverables**

- `docs/research/core-language.md`: 8–12 family interviews on «партия», roles, units and quick actions.
- `docs/decisions/build-freeze.md`: target markets, OS versions, relative permissions, recovery, voice scope, free limits.
- `docs/adr/0001-local-data-stack.md`: SQLite/encryption/state package choice after minimal spikes.
- `docs/adr/0002-sync-contract.md`: command/event/change-feed decision and rejected alternatives.

**Work**

- Prototype paper/click flows from `PRODUCT_SPEC.md:408` and test create/take/find-location.
- Include users with weak vision or motor constraints before visual freeze (`DESIGN.md:295`).
- Instrumentally verify candidate palette contrast; update `DESIGN.md:111` rather than hardcoding it.
- Approve safety copy deny-list and escalation owner.

**Exit**

- All high-impact open questions have owner/decision/date.
- No evidence contradicts the party aggregate or event-log model.
- Large-mode core task success reaches ≥ 85% on the prototype or the flow is revised.

### 1. Bootstrap and quality gates — R1 DONE

**Target paths**

- `apps/mobile/pubspec.yaml`, `apps/mobile/lib/main.dart`.
- `apps/mobile/analysis_options.yaml`.
- `apps/mobile/test/`, `apps/mobile/integration_test/`.
- CI workflow chosen by repository owner.

**Work**

- Pin Flutter SDK/toolchain and dependency lockfile.
- Create flavor/config boundary for local, staging and production without committed secrets.
- Establish module dependency rule: UI → application/repository interfaces → domain; infrastructure implements interfaces.
- Add format, analyze, unit/widget/integration, golden and semantics gates.
- Add logging redaction and crash reporting interface disabled until privacy decision.

**Exit**

- Empty app builds on one iOS and one Android target.
- `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test` pass.
- A smoke `flutter test integration_test` launches the app on selected targets.

### 2. Local domain, SQLite and projection foundation — R1 functional subset DONE; full-plan encryption/property/crash gates pending

**Target paths**

- `packages/domain/lib/src/{family,batch,location,inventory,sync}/` or approved in-app equivalent.
- `apps/mobile/lib/core/database/`.
- `apps/mobile/lib/core/sync/local_operation_queue.dart`.

**Work**

- Implement client UUIDs, device sequence, idempotency keys, events and commands from `PRODUCT_SPEC.md:206`.
- Create versioned SQLite migrations for family, membership, batch, location, events, operations, projections and tombstones.
- One database transaction handles local intent → pending operation → event → projection.
- Implement deterministic projection rebuild and invariant checker.
- Add app-private encryption key lifecycle and migration backup/restore.

**Tests**

- Property tests for arbitrary event sequences and inverse/reconciliation events.
- Crash-point tests around every transaction boundary.
- Migration forward tests from every released schema fixture.
- Duplicate operation and corrupted payload tests.

**Exit**

- 100,000 generated event sequences rebuild deterministically.
- No crash point loses a committed local operation.

### 3. First vertical slice: create, view, take, history — R1 functional subset DONE; golden/performance evidence pending

**Target paths**

- `apps/mobile/lib/features/batches/`.
- `apps/mobile/lib/features/inventory/`.
- `apps/mobile/lib/features/history/`.
- `apps/mobile/lib/design_system/`.

**Work**

- Build only the quick create fields first: name, positive quantity, location.
- Implement batch card/details, `QuantityDisplay`, «Взял 1», «Взял несколько», return, spoil, undo and reconciliation.
- Render local data only through repository projections.
- Implement history rows and pending/synced/attention presentation.
- Apply `DESIGN.md:97`, component contract at `DESIGN.md:151` and state rules at `DESIGN.md:222`.

**Tests**

- Unit/widget/golden tests for every quantity transition and invalid input.
- 100%/200% text, normal/large mode and semantics snapshots.
- Integration flow in airplane mode: create → take → kill → relaunch → history.

**Exit**

- Core slice works without backend and meets local speed targets.

### 4. Locations, catalog and search — R1 functional subset DONE; 5,000-row performance gate pending

**Target paths**

- `apps/mobile/lib/features/locations/`.
- `apps/mobile/lib/features/batches/catalog/`.

**Work**

- Implement adjacency tree with max depth 6, no cycles, move/delete safeguards and breadcrumb.
- Build catalog/read model, normalized Cyrillic search, combined filters and derived statuses.
- Build phone, tablet and row/grid variants without divergent business logic.
- Seed benchmark fixture with 5,000 batches and realistic location depth.

**Tests**

- Cycle/depth/property tests, non-empty deletion flow, same-name locations.
- Search `ё/е`, case and whitespace normalization tests.
- Device performance profile and regression threshold.

**Exit**

- Catalog performance and `PRODUCT_SPEC.md:714` acceptance criteria pass on reference device.

### 5. Supabase schema, RLS and transactional command API

**Target paths**

- `supabase/migrations/*_initial_core.sql`.
- `supabase/functions/sync-push/`, `supabase/functions/sync-snapshot/` or approved RPC equivalents.
- `supabase/tests/database/*_test.sql`.
- `docs/threat-model.md`.

**Work**

- Convert `PRODUCT_SPEC.md:858` draft into normalized migrations with composite family-consistency constraints.
- Implement auth/bootstrap users, families, memberships, devices, invite hashes/rate limits.
- Enable RLS on every exposed table and private Storage bucket.
- Revoke event/projection direct writes; accept commands through narrow transactional RPC/API.
- Atomically persist operation, domain events, entity/projection changes and change feed.
- Add append-only triggers, payload validation, role/capability functions and audit.

**Tests**

- pgTAP schema, constraints, functions and RLS matrix for every role/family pair.
- Idempotency, transaction rollback and forged family/batch/device references.
- Storage object access across families.
- Static SQL lint and secret scan.

**Exit**

- `supabase db reset`, `supabase db lint --level error` and `supabase test db` pass locally.
- Cross-tenant test matrix has zero unauthorized reads/writes.

### 6. Sync engine and conflict recovery

**Target paths**

- `apps/mobile/lib/core/sync/`.
- `apps/mobile/integration_test/sync_*_test.dart`.
- backend sync functions/RPC and database tests.

**Work**

- Push ordered operations with backoff/jitter and stable rejection codes.
- Pull cursor changes transactionally; implement snapshot bootstrap and schema compatibility gate.
- Use Realtime only to wake pull, with periodic/foreground fallback.
- Implement field-level metadata merge records, tombstones, revocation and underflow reconciliation.
- Add support diagnostics that redact names, comments, photos and tokens.

**Fault matrix**

- offline for 24 hours;
- app kill at four transaction/network points;
- duplicate/reordered/delayed responses;
- missed Realtime signal;
- bad device clock/timezone;
- expired/revoked membership;
- old client schema;
- two-device underflow and same-field edit.

**Exit**

- Two-device convergence and zero-loss criteria pass for the full fault matrix.
- User-facing outcomes match `PRODUCT_SPEC.md:309` without technical jargon.

### 7. Family onboarding and access lifecycle

**Target paths**

- `apps/mobile/lib/features/onboarding/`.
- `apps/mobile/lib/features/settings/family/`.
- invite backend function/RPC and RLS tests.

**Work**

- Create/join family, safe invite preview, role preset and expiry/revoke.
- Implement optional identity linking/recovery based on Step 0 decision.
- Protect last-admin, re-auth sensitive actions and membership revocation.
- Offer large mode to every user without age labeling.
- Ask camera/microphone permissions in context, never during generic onboarding.

**Tests**

- Expired/reused/brute-forced invite, last admin, role change and removed-device flows.
- Cold onboarding timing and accessibility walkthrough.

**Exit**

- Invite completion and onboarding criteria pass without mandatory phone entry.

### 8. QR and media

**Target paths**

- `apps/mobile/lib/features/qr/`.
- `apps/mobile/lib/features/batches/media/`.
- private Storage policy/migration and upload functions.

**Work**

- Generate opaque label token + short code; scan, manual entry, link/unlink/revoke.
- Cache only already-authorized resolves for offline use.
- Capture/resize/orient/strip EXIF; queue upload with checksum and retry.
- Keep batch/event success independent from media upload.

**Tests**

- QR payload privacy inspection, screenshot/revocation, foreign-family resolve and damaged/manual code.
- Camera denied, storage full, interrupted upload, duplicate complete and corrupt checksum.
- At least one physical-device integration test per platform for camera/plugin boundary.

**Exit**

- QR/media acceptance criteria from `PRODUCT_SPEC.md:701` pass on iOS and Android physical devices.

### 9. Accessibility, tablet and content hardening

**Target paths**

- shared design-system tests and golden matrix.
- `docs/qa/accessibility-matrix.md`.
- `docs/qa/content-audit.md`.

**Work**

- Complete large-mode home, rows/grid and all core error/recovery states.
- Implement tablet navigation rail/master-detail and one-hand phone action zones.
- Run Flutter guideline tests for target size, contrast and labels.
- Run VoiceOver, TalkBack, Switch Access, 200% text, reduced motion and low-vision sessions.
- Audit all safety, technical and blame-oriented copy against `DESIGN.md:248`.

**Exit**

- Automated and manual accessibility criteria pass; unresolved physical-device issues block beta.

### 10. Observability, export and beta readiness

**Target paths**

- `apps/mobile/lib/core/telemetry/`.
- `docs/privacy-retention.md`.
- `docs/qa/beta-release-checklist.md`.
- export/restore implementation and fixtures.

**Work**

- Implement allowlisted telemetry from `PRODUCT_SPEC.md:1322` with consent/opt-out.
- Add sync/projection/data-loss alerts without content payload.
- Implement minimal JSON export and restore drill.
- Run threat-model review, dependency/license scan, privacy review and store copy audit.
- Prepare reversible beta rollout, support diagnostics and stop conditions.

**Exit**

- Export restores counts/events/checksums in a clean family.
- No critical/high data-loss, privacy, RLS or safety findings remain.
- Release 1 exit criteria at `PRODUCT_SPEC.md:584` are measured and signed off.

## Verification Steps

### Every change

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Run from the Flutter package directory until a root task runner exists.

### Database/API changes

```bash
supabase db reset
supabase db lint --level error
supabase test db
```

Never use `supabase db reset --linked` in this workflow; linked reset is destructive. Remote deploy/publish remains separately approved work.

### Release candidate

```bash
flutter test integration_test
```

Additionally required:

- iOS and Android physical-device camera/QR/offline/sync runs;
- fault-injection two-device matrix;
- 5,000-row performance fixture on reference low-tier device;
- VoiceOver/TalkBack/accessibility scanner and human large-mode sessions;
- export → clean restore → invariant/checksum comparison;
- copy deny-list and manual safety review;
- pgTAP RLS matrix and Storage cross-tenant tests.

### Official command references checked 2026-07-19

- Flutter integration tests: <https://docs.flutter.dev/testing/integration-tests>
- Flutter accessibility testing: <https://docs.flutter.dev/ui/accessibility/accessibility-testing>
- Supabase local migrations: <https://supabase.com/docs/guides/local-development/overview>
- Supabase database testing/linting: <https://supabase.com/docs/guides/local-development/cli/testing-and-linting>

## Risks and Mitigations

| Risk | Mitigation | Stop rule |
|---|---|---|
| Sync architecture built too late | local operation envelope and two-device vertical slice by Step 6, before QR/media polish | stop feature work after first convergence failure until zero-loss proof |
| Package-driven architecture sprawl | ADR spikes, repository contract, dependency rules | reject a library that needs UI to bypass repository |
| RLS false confidence | deny-by-default, pgTAP role/family matrix, Storage tests | any cross-tenant access blocks all beta |
| Accessibility postponed | components + semantics/goldens from first vertical slice | core large-mode failure blocks beta |
| Voice scope expands | OS dictation default, app parser only after research | no custom ASR before written build-freeze decision |
| Photo pipeline blocks inventory | independent queue and attach operation | text/event flows may not depend on upload success |
| Season features contaminate MVP | schema extension points only, P2 feature flags absent from UI | no request/recipe/analytics UI before Release 1 exit |
| Safety wording drifts | central string audit/deny-list + legal owner | any certainty claim blocks release |
| No real user habit | beta metrics and physical reconciliation | do not start Release 2 if event coverage/accuracy miss targets without corrective study |

## Definition of Done

MVP считается завершённым только когда P0 реализован, все automated gates проходят, physical-device/accessibility/fault tests имеют сохранённые артефакты, beta exit metrics измерены, а нерешённые high risks отсутствуют. Наличие красивых экранов без zero-loss sync и реального крупного режима — это не MVP, а нарядная банка с воздухом.
