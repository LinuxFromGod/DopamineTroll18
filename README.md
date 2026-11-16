# FakeDopamine

Автономное iOS-приложение, которое полностью **имитирует** Dopamine 3.0.13:
реальный интерфейс, реальная последовательность логов, boot-экран, паника ядра,
выбор менеджера пакетов и смена темы. При этом оно **ничего не делает с системой**:
нет `libjailbreak`, нет эксплойтов, нет записи в системные разделы и нет самого
джейлбрейка.

Приложение можно собрать и запустить в симуляторе iPhone без подписи. Для сборки
требуются macOS и Xcode; GitHub Actions выполняет сборку на macOS runner и
публикует `.app` симулятора как workflow artifact.

## Что умеет

- Полный сценарий «джейлбрейка»: patchfinding → kernel exploit → PAC/PPL/SPTM bypass →
  phys R/W → bootstrap → trust cache → environment → protection → bind mount.
- Живой лог в стиле Dopamine (анимированные строки) и подробный debug-лог.
- Экран выбора Sileo/Zebra при первом запуске.
- Настройки: эксплойты, tweak injection, verbose logs, App JIT, jetsam multiplier,
  удаление джейлбрейка, тема, boot-логотип, сброс настроек.
- Симуляция respring и userspace reboot с прогресс-баром.
- Режим `Kernel Panic`: реалистичный panic dump, после которого «устройство
  перезагружается» и состояние джейлбрейка сбрасывается. Паника также случайно
  случается в ~7% обычных запусков.
- Смена иконки приложения вместе с темой (AppIcon_ElleKit / Red / Purple / Blue).
- Русская, английская, немецкая, испанская и французская локализации.

## Требования

- macOS с Xcode 15 или новее (подойдёт и Xcode 16).
- iOS Simulator с iOS 15.0+.
- Для запуска на реальном устройстве — Apple ID / development team в Xcode.

## Сборка и запуск

1. Откройте `FakeDopamine.xcodeproj` в Xcode.
2. Выберите схему `FakeDopamine` и любой iPhone-симулятор.
3. Нажмите **Run** (⌘R).

### GitHub Actions

Workflow `.github/workflows/ios-build.yml` собирает Release-версию для iOS Simulator
при push в `main`, pull request и вручную через **Actions → iOS Build → Run workflow**.
Готовый `FakeDopamine.app` доступен в артефакте `FakeDopamine-iOS-Simulator` в течение
14 дней. Эта сборка не подписана и предназначена только для симулятора.

Для запуска на устройстве:

1. Откройте таргет `FakeDopamine` → **Signing & Capabilities**.
2. Выберите свою команду в **Team**.
3. При необходимости смените `PRODUCT_BUNDLE_IDENTIFIER`
   (по умолчанию `com.margisko.fakedopamine`).
4. Соберите и запустите на подключённом iPhone.

Дисплейное имя приложения — **Dopamine**, имя проекта и таргета — `FakeDopamine`.

## Как пользоваться

1. Запустите приложение.
2. Нажмите большую кнопку **Jailbreak**.
3. Если менеджеры пакетов ещё не выбраны, выберите Sileo и/или Zebra и нажмите
   **Continue**.
4. Дождитесь окончания лога: приложение покажет boot-экран (или панику) и
   «перезапустится» уже в состоянии «Jailbroken».
5. После этого доступны настройки, respring и userspace reboot.

Сбросить всё состояние можно через **Settings → Reset Settings** или удалив
приложение (настройки хранятся в `NSUserDefaults` под ключом `DOPreferences`).

## Структура

```
FakeDopamine/
├── FakeDopamine.xcodeproj/          # проект и shared-схема
├── FakeDopamine/
│   ├── App Delegates/               # UIApplication / UIScene delegates
│   ├── Boot/                        # boot-экран и экран kernel panic
│   ├── Fake/                        # симуляция: окружение, «джейлбрейкер», настройки
│   ├── Settings/                    # экран настроек, credits, общий стиль
│   ├── UI/                          # основной экран, лог, меню, темы, переходы
│   ├── *.lproj/                     # локализации
│   ├── Assets.xcassets/             # иконки, фоны, boot-логотип
│   └── Info.plist
└── LICENSE.md                       # MIT, оригинальный Dopamine
```

## Важно

- Это **симулятор**, а не джейлбрейк. Он не устанавливает пакеты, не меняет
  систему и не требует эксплойтов.
- Все «системные» действия (respring, reboot, panic) — визуальная имитация.
- Исходники интерфейса основаны на Dopamine 3.0.13 (MIT, © Lars Fröder / opa334).
  См. `LICENSE.md`.
