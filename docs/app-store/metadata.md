# App Store metadata — Bottle of Water 1.0

Limits: name and subtitle 30 characters, promotional text 170, keywords 100 bytes, description 4000.

## General

| Field | Value |
|---|---|
| Bundle ID | `com.vlasov.bottleofwater` |
| SKU | `bottleofwater-ios` |
| Primary category | Health & Fitness |
| Secondary category | Lifestyle |
| Age rating | 4+ (no objectionable content) |
| Price | Free |
| Copyright | 2026 Viktor Vlasov |
| Support URL | https://viktor100500.github.io/BottleOfWater/ |
| Privacy Policy URL | https://viktor100500.github.io/BottleOfWater/privacy/ |
| App Privacy | **Data Not Collected** |
| Encryption | Uses no non-exempt encryption (`ITSAppUsesNonExemptEncryption = NO`) |

Screenshots (6.9", 1320×2868): `docs/app-store/screenshots/en` and `.../ru`. App Store Connect scales them to smaller iPhones.

---

## English (U.S.)

**Name:** Bottle of Water
(if taken: `Bottle of Water: Hydration`)

**Subtitle:** Water tracker & reminders

**Promotional text:**
Log a glass in one tap from the app, widgets, Control Center or Siri. Smart reminders stay quiet after you drink and stop once you hit your goal.

**Keywords:**
`hydration,drink,reminder,tracker,intake,habit,health,widget,daily goal,log,cup,oz,hydrate,aqua`

**Description:**
```
Bottle of Water is the fastest way to drink a little more water every day — without thinking about it.

ONE TAP, ANYWHERE
• Tap a preset to log a glass, cup, can or bottle
• Any amount with a big, easy keypad — in ml or fl oz
• Home Screen and Lock Screen widgets with quick-add buttons
• A Control Center and Action Button control
• Siri and Shortcuts: “Log water in Bottle of Water”
• Log right from a reminder, without opening the app

REMINDERS THAT GET YOU
• Every N minutes during your day, or at specific times
• Logging a drink restarts the timer — no nagging right after a glass
• Reminders pause once you reach your daily goal

SEE YOUR PROGRESS
• A liquid gauge that fills up as you drink
• Week, month, 6-month and year charts with your goal line
• Daily average, goal days, current and best streak
• Forgot to log? Add or edit drinks for any day

APPLE HEALTH
Every drink is saved to Apple Health as Dietary Water, and edits and deletions stay in sync. Bottle of Water only writes water data — it never reads your health data.

PRIVATE BY DESIGN
No accounts, no ads, no analytics, no servers. Your data stays on your iPhone and in Apple Health.

Bottle of Water is not a medical device. Hydration needs vary with health, activity and climate — ask a doctor if you’re unsure.
```

**What’s New (1.0):**
```
First release. Cheers! 💧
```

---

## Russian

**Name:** Bottle of Water

**Subtitle:** Трекер воды и напоминания

**Promotional text:**
Отмечайте стакан в одно касание — в приложении, виджете, Пункте управления или через Siri. Умные напоминания молчат после глотка и стихают, когда цель выполнена.

**Keywords:**
`вода,пить,норма,напоминание,трекер,баланс,виджет`
(≤100 bytes: App Store Connect counts Cyrillic as 2 bytes per letter)

**Description:**
```
Bottle of Water — самый быстрый способ пить чуть больше воды каждый день и не думать об этом.

ОДНО КАСАНИЕ — ГДЕ УГОДНО
• Пресеты: глоток, стакан, чашка, банка, бутылка
• Любой объём на большой удобной клавиатуре — в мл или унциях
• Виджеты для экрана «Домой» и экрана блокировки с быстрыми кнопками
• Кнопка в Пункте управления и на кнопке действия
• Siri и Команды: «Записать воду в Bottle of Water»
• Отметка прямо из напоминания, не открывая приложение

НАПОМИНАНИЯ, КОТОРЫЕ НЕ РАЗДРАЖАЮТ
• Каждые N минут в течение дня или в точное время
• Каждая запись перезапускает таймер — никаких напоминаний сразу после стакана
• После выполнения цели напоминания затихают до завтра

ПРОГРЕСС НАГЛЯДНО
• «Жидкая» шкала, которая наполняется по мере того, как вы пьёте
• Графики за неделю, месяц, полгода и год с линией цели
• Среднее в день, дни с выполненной целью, текущая и лучшая серия
• Забыли отметить? Добавьте или исправьте запись за любой день

APPLE HEALTH
Каждая запись сохраняется в Apple Health как «Вода», изменения и удаления синхронизируются. Приложение только записывает данные о воде и никогда не читает ваши данные о здоровье.

ПРИВАТНОСТЬ ПО УМОЛЧАНИЮ
Без аккаунтов, рекламы, аналитики и серверов. Данные остаются на iPhone и в Apple Health.

Bottle of Water не является медицинским изделием. Потребность в воде зависит от здоровья, активности и климата — если сомневаетесь, посоветуйтесь с врачом.
```

**What’s New (1.0):**
```
Первый релиз. Ваше здоровье! 💧
```

---

## App Review notes

```
Bottle of Water is a water intake tracker. No account or login is required.

Apple Health: the app requests WRITE access to Dietary Water only and never reads health data. Each logged drink is saved as an HKQuantitySample with a sync identifier, so edits replace the sample and deletions remove it. The app is fully usable if Health access is declined.

To try the main features:
1. Complete the 3-step onboarding (goal, optional Health and reminders).
2. Tap a preset on the Today tab; the entry appears in the log and in Apple Health.
3. Tap "Other" or "+" to enter a custom amount with the in-app keypad.
4. Tap an entry to edit or delete it; History → a day → "+" adds a past entry.
5. Settings → Reminders: interval or specific times; reminders include "+amount" actions.
6. Home Screen widget, Control Center control and Siri ("Log water in Bottle of Water").

The app has no network access, analytics or third-party SDKs.
```
