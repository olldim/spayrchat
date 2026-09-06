# Збірка Spayr через Codemagic

Власний Mac не потрібен: iOS компілюється на Mac-машині Codemagic. Для вашого способу встановлення створюється **непідписана IPA**, яку потім підписує AltStore/Sideloadly. Apple Team, provisioning profile і сертифікат у цьому CI-сценарії не потрібні.

## Що змінено після ERRORS.txt

**Android.** У журналі точний збій — `Failed to find target with hash string 'android-37'`. `flutter_secure_storage 11.0.0` задає `compileSdk = 37`, а SDK у цьому запуску встановився в `platforms/android-37.0`. Зафіксовано `flutter_secure_storage: 10.3.1`, який використовує API 36; `compileSdk` застосунку теж дорівнює 36. Оновлений `pubspec.lock` треба завантажити разом із `pubspec.yaml`. Попередження про Kotlin у `flutter_webrtc` не було причиною цього збою, тому версію WebRTC збережено.

**iOS.** Повідомлення про Development Team недостатньо для встановлення справжньої причини: у Flutter 3.44.1 це може бути загальна діагностика після невдалої збірки для пристрою. Сам `--no-codesign` уже вимикає підписання, тому з наданого уривка не можна зробити висновок, що проблема лише в сертифікатах. Новий сценарій готує проєкт через Flutter, збирає через `xcodebuild` з явними параметрами непідписаної збірки та зберігає повний Xcode-журнал і `.xcresult`. Це усуває неоднозначність наступного звіту; успішність iOS-компіляції потрібно підтвердити запуском Codemagic.

**Середовище.** У YAML закріплено Flutter **3.44.1**, для iOS — Xcode **26.3**, для Android — Java **17** та Android SDK **36**. Це прибирає залежність від мінливого значення `stable` у налаштуваннях Codemagic. `flutter clean` виконується тільки на CI-машині, а `flutter pub get --enforce-lockfile` відновлює залежності й локальні шляхи саме там. Не потрібно вручну редагувати `Generated.xcconfig` чи додавати Podfile до цього проєкту зі Swift Package Manager.

## Що зробити зараз

1. Завантажте зміни в ту гілку репозиторію, з якої збирає Codemagic. Особливо важливі **`codemagic.yaml`**, **вся папка `ci/`**, **`pubspec.yaml`**, **`pubspec.lock`**, **`android/app/build.gradle.kts`**, **`test/widget_test.dart`** та **`.gitattributes`**.
2. У Codemagic відкрийте застосунок і перейдіть до конфігурації **`codemagic.yaml`**. Виберіть потрібну гілку та натисніть **Check for configuration file**. Старі налаштування Workflow Editor самі по собі не запускають додані YAML-сценарії.
3. Запустіть потрібний workflow:

| Workflow ID | Що отримаєте |
| --- | --- |
| `android` | `app-release.apk` та `app-release.aab` |
| `ios-unsigned` | `Spayr-unsigned.ipa` для подальшого підписання |

4. Завантажте файл із **Artifacts**. IPA спочатку відкрийте в AltStore/Sideloadly для підписання, а не встановлюйте як уже підписаний застосунок.

Автоматичного завантаження до Google Play, App Store чи TestFlight немає. Android-артефакти зараз використовують тестовий debug-ключ із наявного шаблону проєкту: APK підходить для перевірки, для Google Play потрібен ваш release keystore.

## Як влаштована iOS-збірка

`ci/build_ios_unsigned.sh` застосовує `ci/ios-unsigned.xcconfig` лише до поточного процесу CI. У ньому `CODE_SIGNING_ALLOWED=NO`, `CODE_SIGNING_REQUIRED=NO`, очищені identity/team/provisioning/entitlements для цього непідписаного артефакту. Звичайні налаштування проєкту та `ios/Runner/Runner.entitlements` залишаються у вихідному коді.

Після успішної компіляції скрипт копіює весь `Runner.app`, включно з Flutter/WebRTC frameworks та ресурсами, в `Payload/Runner.app` і створює нову IPA. Помилка Flutter або Xcode зупиняє сценарій; старий IPA не видається за результат нового запуску.

## Якщо знову буде помилка

У нових сценаріях достатньо завантажити відповідний артефакт журналу:

- Android: `android-apk.log` або `android-aab.log`; якщо збій на встановленні SDK — `android-sdk.log`.
- iOS: **`ios-xcodebuild.log`**; якщо компіляція ще не почалася — **`ios-configure.log`**. Додатково зберігається **`xcode-result.zip`**, якщо Xcode встиг створити `.xcresult`.
- Версії інструментів: `flutter-version.log`, `xcode-version.log`, `java.log`.
- Залежності й тести: `pub-get.log`, `flutter-analyze.log`, `flutter-test.log`.

Не обрізайте журнал до останнього загального повідомлення про Team: конкретна помилка може бути раніше. Жодних паролів Apple чи сертифікатів для цього сценарію передавати не треба.

## Локальна перевірка на Windows

```powershell
flutter pub get --enforce-lockfile
flutter analyze
flutter test
python ci/test_ci_scripts.py
```

На Codemagic той самий набір Flutter-тестів запускається з `--dart-define=SPAYR_CHECK_GOLDENS=false`: функціональні перевірки й перевірки переповнення екранів збережено, але зображення шрифтів на macOS не порівнюються побітово зі знімками Windows. Локально порівняння знімків залишається увімкненим.

Тести скрипта на Windows підміняють Flutter/Xcode контрольованими командами: перевіряються коди помилок, збереження журналу й структура IPA. **Вони не є реальною iOS-компіляцією.** У цьому середовищі немає Mac/Xcode та Android SDK, тому остаточний результат перевіряється новим запуском Codemagic.

Документація: [Flutter workflows у Codemagic](https://docs.codemagic.io/yaml-quick-start/building-a-flutter-app/), [образ Xcode 26.3](https://docs.codemagic.io/specs-macos/xcode-26-3/), [зміни flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage/changelog).
