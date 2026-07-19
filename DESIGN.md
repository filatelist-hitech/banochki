# Design

## Source of truth

- Status: Draft
- Last refreshed: 2026-07-19
- Primary product surfaces: Flutter mobile app for iOS/Android, adaptive tablet layout, offline and family-shared states.
- Canonical product specification: `PRODUCT_SPEC.md`.
- Evidence reviewed: user brief at `/Users/filatelist/.codex/attachments/a8963a54-ea4b-4d66-97de-f24c4b8c8958/pasted-text.txt`; repository inspection found no existing UI, brand assets, components, screenshots, or frontend conventions.
- Governance: product behavior, data rules and acceptance criteria live in `PRODUCT_SPEC.md`; this file governs UI/UX, visual language and interaction decisions. A contradiction blocks implementation until one of the documents is updated.

## Brand

- Personality: домашний, спокойный, уважительный, практичный, местами с мягким юмором.
- Product metaphor: семейный цифровой погреб, а не складская панель.
- Trust signals: явный остаток, понятная история, имя автора действия, точное место, честный offline/sync state, обратимое исправление.
- Avoid: корпоративные таблицы, индустриальные штрихкоды как эстетика, «умная магия», infantilization, тревожные красные баннеры, деревенский китч, визуальная перегрузка банками и соленьями.
- Brand line: «Что осталось — видно семье».

## Product goals

- Goals:
  - дать честный ответ «что, сколько, где, кто взял» за несколько секунд;
  - сделать запись движения легче, чем сообщение в семейный чат;
  - обеспечить first-class offline и крупный режим;
  - создать доверие через append-only history и понятное исправление;
  - подготовить основу для сезонной памяти без перегрузки MVP.
- Non-goals:
  - складской, финансовый или поштучный учёт;
  - safety certification;
  - recipe-first или AI-first experience;
  - обязательный аккаунт по телефону;
  - сложная аналитика в первом релизе.
- Success signals:
  - p50 «Взял 1» не больше 5 секунд и двух явных нажатий после открытия партии;
  - p50 первой партии не больше 3 минут;
  - не менее 85% ключевых задач крупного режима завершаются без помощи в тестах;
  - reconciliation accuracy не ниже 90% после четырёх недель beta;
  - sync loss rate равен нулю в fault-injection tests.

## Personas and jobs

- Primary personas:
  - хранитель: создаёт партии, места, уточняет остаток;
  - участник семьи: ищет и отмечает движения;
  - родственник: получает ограниченный доступ к просмотру и разрешённым действиям;
  - администратор: управляет семьёй, правами, восстановлением и экспортом.
- User jobs:
  - быстро записать новую партию;
  - увидеть наличие и место;
  - отметить «взял/вернул/испорчено/переместил»;
  - понять, кто и когда изменил остаток;
  - исправить расхождение без удаления истории;
  - позже повторить удачную партию и спланировать сезон.
- Key contexts of use:
  - холодный/тёмный погреб, слабая сеть или её отсутствие;
  - одна рука занята коробкой или банкой;
  - слабое зрение, крупный системный текст, неуверенное владение смартфоном;
  - быстрый просмотр дома перед поездкой на дачу;
  - телефон и планшет, иногда общий семейный device.

## Information architecture

- Primary navigation, normal mode:
  - «Что осталось»;
  - «Все запасы»;
  - «Сканер»;
  - «История семьи»;
  - «Ещё».
- Primary navigation, large mode:
  - «Что есть»;
  - «Добавить партию»;
  - «Взял банку»;
  - «Где лежит»;
  - secondary «История» и «Помощь».
- Core routes/screens:
  - onboarding create/join;
  - home/status groups;
  - catalog/search/filter;
  - batch details/history/actions/edit;
  - quick add and voice draft;
  - QR scan/resolve/link;
  - location tree/content;
  - family/members/invites;
  - sync details/attention resolution;
  - settings/privacy/export.
- Content hierarchy on batch screen:
  1. название и фото;
  2. остаток;
  3. место;
  4. «Взял 1» / «Взял несколько»;
  5. другие движения;
  6. sync state;
  7. детали и история;
  8. осторожный check reminder при необходимости.

## Design principles

- **Правда раньше декора.** Остаток, место и история визуально важнее фото, тегов и статистики.
- **Сначала сохранить, потом дополнить.** Три обязательных значения создают партию; остальные поля progressive.
- **Явное действие сильнее жеста.** У каждого ключевого действия есть подписанная кнопка.
- **Offline — нормальное состояние.** UI подтверждает локальную запись и не пугает отсутствием сети.
- **Исправление без стирания.** Ошибки отменяются/уточняются компенсирующим действием.
- **Крупный режим — равноправный продукт.** Он использует те же данные и термины, а не урезанную отдельную логику.
- Tradeoffs:
  - скорость core flow важнее полноты формы;
  - читаемость важнее плотности информации;
  - сохранение фактических offline-действий важнее красивого «никогда не ниже нуля» в backend;
  - privacy и подтверждение важнее скорости AI/CV.

## Visual language

- Color, provisional accessible palette:
  - `canvas`: `#FFF8EE` — тёплый нейтральный фон;
  - `surface`: `#FFFFFF`;
  - `ink`: `#241B16` — основной текст;
  - `muted-ink`: `#63564E`;
  - `primary`: `#943F27` — терракотовое действие;
  - `primary-on`: `#FFFFFF`;
  - `support`: `#3F6A52` — спокойное подтверждение;
  - `attention`: `#8A4B08`;
  - `danger`: `#982D2D`;
  - цвета считаются кандидатами до инструментальной проверки WCAG contrast во всех состояниях.
- Typography:
  - MVP использует platform system sans для читаемости, производительности и корректного large text;
  - normal body 17–18 sp, large-mode body ≥ 20 sp;
  - normal primary action 18–20 sp, large-mode action 22–26 sp;
  - quantity display 40–56 sp;
  - не больше трёх весов шрифта на экране, без all caps.
- Spacing/layout rhythm:
  - базовый шаг 8 dp;
  - phone side padding 16 dp, large mode 20–24 dp;
  - section gap 24–32 dp;
  - primary action height 56–64 dp, large mode 64–72 dp;
  - плотность не повышается ради показа «ещё одной карточки».
- Shape/radius/elevation:
  - radius 12 dp для controls, 16–20 dp для cards;
  - бордер и тональное различие предпочтительнее тяжёлых теней;
  - floating elements используются только для global add/scan при доказанной доступности.
- Motion:
  - 150–250 ms для state transition;
  - quantity change может использовать короткий scale/fade + haptic;
  - reduced motion отключает scale/parallax и оставляет мгновенное текстовое подтверждение;
  - никаких бесконечных декоративных анимаций.
- Imagery/iconography:
  - реальные семейные фото партий — основной визуальный материал;
  - иконки простые, округлые, всегда с подписью в core flows;
  - иллюстрации только в onboarding/empty states и не изображают safety certainty;
  - QR остаётся функциональным объектом, не основной визуальной метафорой бренда.

## Components

- Existing components to reuse: отсутствуют; перед implementation нужен минимальный Flutter component inventory.
- New/changed components:
  - `BanochkiScaffold` и adaptive navigation;
  - `PrimaryActionButton`, `SecondaryActionButton`, `DestructiveActionButton`;
  - `QuantityDisplay`, `QuantityStepper`, `QuantityChangeConfirmation`;
  - `BatchCard` variants: compact row, normal card, large tile;
  - `LocationBreadcrumb` и `LocationPicker`;
  - `StatusChip` с текстом + icon/shape;
  - `SyncStateLine` и `SyncAttentionCard`;
  - `HistoryEventRow`;
  - `QuickChoiceGrid`;
  - `VoiceDraftField`;
  - `QrResolveState`;
  - `EmptyState`, `InlineError`, `UndoConfirmation`;
  - `SafeCheckReminder` с утверждённым copy.
- Variants and states:
  - normal/large;
  - row/grid;
  - enabled/pressed/focused/disabled/loading;
  - online/pending/attention;
  - default/low/empty/needs-check/spoiled;
  - photo/no-photo.
- Token/component ownership:
  - единый Flutter theme/tokens package внутри app, без второго ad-hoc design-system слоя;
  - semantic tokens (`surface`, `contentPrimary`, `actionPrimary`, `statusAttention`) вместо цвета сущности;
  - component semantics и golden tests принадлежат компоненту, а не экрану.

## Accessibility

- Target standard: WCAG 2.2 AA как baseline плюс platform guidance iOS/Android; core large-mode flows тестируются с реальными целевыми пользователями.
- Keyboard/focus behavior:
  - logical traversal order; focus не прыгает после обновления остатка;
  - hardware keyboard/switch access доступен на планшете;
  - modal удерживает focus и возвращает его на вызвавшую кнопку;
  - visible focus indicator не зависит только от цвета.
- Contrast/readability:
  - normal text contrast ≥ 4.5:1, large text ≥ 3:1, UI components ≥ 3:1;
  - text scale до 200% без потери действий/контента;
  - minimum target 48×48 dp в обычном режиме, 56×56 dp в крупном;
  - line length на планшете ограничена примерно 60–75 символами.
- Screen-reader semantics:
  - карточка объявляет «Лечо, осталось 7 банок, Дача, Погреб, Полка 1»;
  - action label включает результат: «Взять одну банку лечо»;
  - состояние sync и ошибка объявляются один раз, без live-region спама;
  - декоративные изображения исключены из semantics.
- Reduced motion and sensory considerations:
  - уважать reduced motion;
  - haptic и voice confirmation отдельно выключаемы;
  - важный результат всегда продублирован текстом;
  - звук не используется как единственное подтверждение.

## Responsive behavior

- Supported breakpoints/devices, provisional:
  - compact: `< 600` logical px — single column phone;
  - medium: `600–839` — tablet/large phone, navigation rail where useful;
  - expanded: `≥ 840` — two-pane catalog/detail and persistent action area;
  - exact minimum iOS/Android versions remain open before build freeze.
- Layout adaptations:
  - phone: bottom navigation, detail as route, bottom-safe primary actions;
  - tablet portrait: navigation rail + content, forms remain width-constrained;
  - tablet landscape: master-detail for catalog/location/history;
  - large mode uses fewer columns, never smaller controls to fit more content;
  - system insets, keyboard, split-screen and rotation preserve current draft/action.
- Touch/hover differences:
  - touch is canonical; hover only provides enhancement on pointer tablets;
  - no information exists exclusively in tooltip/hover;
  - one-handed actions sit in reachable lower/middle phone area, destructive action is separated.

## Interaction states

- Loading:
  - local cached content renders first;
  - skeleton only if no cache; spinner не заменяет весь экран при background sync;
  - primary action shows progress only while local atomic transaction completes.
- Empty:
  - «Пока пусто» + одна кнопка «Добавить партию»;
  - filtered empty state предлагает «Сбросить фильтры»;
  - никакой вины и «вы ещё ничего не сделали».
- Error:
  - одна человеческая причина, одна основная repair action, technical details раскрываются отдельно;
  - локально сохранённые данные явно не называются потерянными;
  - permission error не показывает чужие данные.
- Success:
  - новый остаток крупно, короткая фраза и явная «Отменить»;
  - voice/haptic optional;
  - auto-dismiss не уносит единственный undo слишком быстро; history остаётся вторым путём исправления.
- Disabled:
  - кнопка объясняет причину рядом; нельзя полагаться на opacity;
  - отсутствие сети не disabled для local-capable actions.
- Offline/slow network:
  - «На устройстве» рядом с pending action;
  - stale cached data показывает время последнего family sync только в details, не тревожным global banner;
  - «Нужно внимание» появляется только когда требуется решение пользователя.

## Content voice

- Tone: домашний, короткий, точный, уважительный; юмор редкий и не в ошибках/safety.
- Terminology:
  - партия, осталось, место, история, хранитель, крупный режим;
  - «Сохранено для семьи», «На устройстве», «Нужно уточнить»;
  - не использовать SKU, транзакция, конфликт, репликация, elderly mode.
- Microcopy rules:
  - кнопка начинается с простого глагола: «Добавить», «Взял 1», «Переместить сюда»;
  - primary labels 2–6 слов;
  - число и единица всегда рядом;
  - ошибка не обвиняет человека;
  - safety copy никогда не подтверждает съедобность;
  - технические details доступны support, но не стоят на пути core flow;
  - gender-neutral fallback в истории: «Марина: взято 2 банки».

## Implementation constraints

- Framework/styling system:
  - Flutter iOS/Android, adaptive phone/tablet;
  - repository layer — единственный источник UI state;
  - SQLite read-model отображается до сети;
  - platform camera, microphone and accessibility APIs обёрнуты тестируемыми adapters.
- Design-token constraints:
  - semantic tokens, normal/large density modes;
  - системный text scaling не зажимается;
  - contrast проверяется инструментально до утверждения palette;
  - не создавать экранные hex/spacing constants вне token layer.
- Performance constraints:
  - catalog 5 000 batches p95 open/filter < 300 ms на выбранном low-tier устройстве после прогрева;
  - local action feedback < 100 ms p95;
  - image thumbnails lazy, decoded под фактический размер;
  - background sync не блокирует UI thread.
- Compatibility constraints:
  - offline-first, local encryption, RLS, private object storage;
  - camera/microphone denial has full manual fallback;
  - QR payload не содержит PII;
  - no hidden gesture dependency;
  - no safety or AI certainty.
- Test/screenshot expectations:
  - widget tests normal/large, 100%/200% text, light/high-contrast candidates;
  - semantics tests for all core components;
  - golden baselines phone compact, phone large mode, tablet portrait/landscape;
  - VoiceOver/TalkBack manual matrix;
  - low-light/one-hand usability sessions with target users;
  - screenshot copy audit for forbidden safety/technical wording.

## Open questions

- [ ] Product/legal: определить страны запуска и требования privacy/food-safety copy; влияет на consent, retention и stores.
- [ ] Product: утвердить free limits и subscription packaging; влияет на onboarding и storage states.
- [ ] Identity: выбрать recovery flow без обязательного телефона; влияет на data-loss risk.
- [ ] Permissions: relative видит всю семью или allowlisted locations/requests; влияет на RLS модель.
- [ ] Content: утвердить словарь единиц для заморозки, сушёных продуктов и бутылок.
- [ ] Voice: системная диктовка или app-level parser в Release 1; влияет на privacy и сроки.
- [ ] Platform: утвердить minimum iOS/Android и low-tier reference devices.
- [ ] Brand: проверить provisional palette, иконографику и логотип с целевыми пользователями; текущие tokens не финальны.
- [ ] Research: проверить термин «партия» и названия ролей на 8–12 семьях до заморозки copy.
- [ ] Accessibility: включить пользователей со слабым зрением/тремором в тесты до UI freeze, не только после реализации.
