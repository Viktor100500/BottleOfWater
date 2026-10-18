# Чек-лист релиза 1.0

Что уже готово в репозитории: код, тесты, локализация на 11 языков, иконка (light/dark/tinted), Privacy Manifest, сайт поддержки и Privacy Policy (`site/`), метаданные и скриншоты (`docs/app-store/`).

Ниже — шаги, которые требуют вашего аккаунта или решения.

## 1. Блокеры, которые нужно закрыть до отправки

- [ ] **Контакт поддержки.** Выбрать email и подставить его:
  - `Shared/Core/AppGroup.swift` → `AppInfo.supportEmail`;
  - `site/index.html` и `site/privacy/index.html` → заменить все `SUPPORT_EMAIL`.
- [ ] **GitHub Pages.** Settings → Pages → Source: **GitHub Actions**. Workflow `.github/workflows/pages.yml` публикует `site/` при пуше в `main`.
  Для приватного репозитория Pages требует GitHub Pro; иначе сделать репозиторий публичным или разместить `site/` на любом статическом хостинге и поменять `AppInfo.privacyPolicyURL` / `supportURL`.
- [ ] Проверить, что https://viktor100500.github.io/BottleOfWater/privacy/ открывается.

## 2. Apple Developer

- [ ] Identifiers → App IDs `com.vlasov.bottleofwater` и `com.vlasov.bottleofwater.widget`: включены **HealthKit** и **App Groups** (`group.com.vlasov.bottleofwater`).
  При Automatic signing Xcode создаст их сам при первом архиве, но App Group стоит проверить вручную.

## 3. Проверка на реальном iPhone (TestFlight или кабель)

Симулятор всё это не покрывает:
- [ ] Кнопка виджета на экране «Домой» пишет в Health (на устройстве с блокировкой данные Health защищены — запись должна дойти позже, при открытии приложения).
- [ ] Действия «+200 / +330» в уведомлении на заблокированном экране добавляют запись.
- [ ] Кнопка в Пункте управления и на кнопке действия.
- [ ] Siri: «Записать воду в Bottle of Water», «Сколько воды я выпил в Bottle of Water».
- [ ] Напоминания приходят, не приходят сразу после записи и после выполнения цели.
- [ ] Смена дня в полночь: «Сегодня» и виджет обнуляются.
- [ ] Обновление со старой версии (если она стоит на телефоне): записи и цель сохранились.

## 4. Сборка и загрузка

```bash
xcodegen generate
```
Xcode → схема **BottleOfWater** → Any iOS Device → Product → **Archive** → Distribute App → App Store Connect → Upload.
Версия `1.0 (1)` задаётся в `project.yml` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`); для каждой следующей загрузки увеличивать build.

## 5. App Store Connect

- [ ] Создать приложение: iOS, имя «Bottle of Water», bundle ID, SKU `bottleofwater-ios`, основной язык English (U.S.).
- [ ] Заполнить тексты из `docs/app-store/metadata.md` (en и ru).
- [ ] Загрузить скриншоты 6.9″ из `docs/app-store/screenshots/en` и `/ru`.
- [ ] App Privacy → **Data Not Collected**.
- [ ] Возрастной рейтинг 4+, категории Health & Fitness / Lifestyle, цена Free.
- [ ] Review notes — из `metadata.md`.
- [ ] После публикации: вписать App Store ID в `AppInfo.appStoreID` — появится строка «Оценить приложение».

## 6. После релиза (1.1+)

Кандидаты из `docs/REQUIREMENTS.md`, раздел 6: Apple Watch, типы напитков, импорт воды из Health, iCloud.
