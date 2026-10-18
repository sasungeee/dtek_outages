# ДТЕК Відключення (Flutter)

Android-додаток для перегляду графіків відключень **ДТЕК Дніпровські електромережі**  
(https://www.dtek-dnem.com.ua/ua/shutdowns).

<table align="center">
  <tr>
    <th align="center">
      <sup>:warning: WARNING :warning:</sup>
    </th>
  </tr>
  <tr>
    <td align="center">
      Програма була повністю написана за допомогою <a href="https://grok.com">Grok</a>
  </tr>
</table>

## Можливості

- Повноцінний пошук адреси (місто → вулиця → будинок) через AJAX API сайту
- Збереження кількох адрес локально (SharedPreferences)
- Закріплення основної адреси
- При відкритті адреси:
  - причина / поточний статус (як на сайті)
  - графік **сьогодні** і **завтра** (якщо сформовано)
  - якщо графіка немає — текст як на сайті («Очікуйте…» / «Інформація від НЕК ще не надходила»)
- Оновлення: pull-to-refresh і при кожному переході на адресу
- Material Design 3, українська мова

## Збірка

```bash
cd dtek_outages
flutter pub get
flutter build apk --release
```

Потрібен Flutter 3.16+ і Android SDK.

## Структура

```
lib/
  main.dart
  models/
    address.dart      # SavedAddress
    schedule.dart     # SlotStatus, DaySchedule, OutageReason…
  services/
    dtek_api_service.dart  # CSRF + getStreets / getHomeNum
    storage_service.dart   # локальне збереження
  screens/
    home_screen.dart
    add_address_screen.dart
    address_detail_screen.dart
  widgets/
    status_banner.dart
    schedule_timeline.dart
```

## Примітки

- Сайт іноді захищений WAF (Incapsula). Якщо з’являться 403 — спробуйте з іншої мережі або повторіть запит.
- Тижневий «можливий» графік (preset) **не** показується — лише підтверджений `fact` на сьогодні/завтра.
- Група (черга GPV x.y) зберігається разом з адресою після першого запиту.
