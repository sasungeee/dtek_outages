import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../models/schedule.dart';

class DtekApiException implements Exception {
  final String message;
  final int? statusCode;

  DtekApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class DtekApiService {
  static const _baseUrl = 'https://www.dtek-dnem.com.ua';
  static const _ajaxPath = '/ua/ajax';
  static const _pagePath = '/ua/shutdowns';

  late final Dio _dio;
  String? _csrfToken;
  DateTime? _csrfFetchedAt;
  final Map<String, String> _cookies = {};

  static const msgNoBlackout =
      'Якщо в даний момент у вас відсутнє світло, імовірно виникла аварійна ситуація, або діють стабілізаційні або екстрені відключення. Просимо перевірити інформацію через 15 хвилин, саме стільки часу потрібно для оновлення даних на сайті.';
  static const msgExtra =
      'У разі відсутності світла у зоні, що гарантує його наявність (на графіку – білий колір), оформіть заявку нижче.';
  static const msgTodayEmpty = 'Очікуйте на оновлення графіків';
  static const msgTomorrowEmpty =
      'Інформація від НЕК «Укренерго» про обмеження на наступний день ще не надходила';
  static const msgMultiGroup =
      'Ваш будинок має складну схему підключення — він під’єднаний до різних ліній електропередачі, через що квартири можуть відключатися за різними графіками';

  DtekApiService({Dio? dio}) {
    _dio = dio ??
        Dio(BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 25),
          receiveTimeout: const Duration(seconds: 30),
          followRedirects: true,
          validateStatus: (s) => s != null && s < 500,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36',
            'Accept-Language': 'uk-UA,uk;q=0.9,en-US;q=0.8,en;q=0.7',
          },
        ));
  }

  void _captureCookies(Response resp) {
    final setCookies = resp.headers.map['set-cookie'];
    if (setCookies == null) return;
    for (final raw in setCookies) {
      final part = raw.split(';').first.trim();
      final eq = part.indexOf('=');
      if (eq <= 0) continue;
      final name = part.substring(0, eq).trim();
      final value = part.substring(eq + 1).trim();
      if (name.isNotEmpty) {
        _cookies[name] = value;
      }
    }
  }

  String? get _cookieHeader {
    if (_cookies.isEmpty) return null;
    return _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  Future<void> _ensureSession({bool force = false}) async {
    if (!force &&
        _csrfToken != null &&
        _csrfFetchedAt != null &&
        DateTime.now().difference(_csrfFetchedAt!) <
            const Duration(minutes: 15)) {
      return;
    }

    final resp = await _dio.get(
      _pagePath,
      options: Options(
        headers: {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          if (_cookieHeader != null) 'Cookie': _cookieHeader,
        },
        responseType: ResponseType.plain,
      ),
    );
    _captureCookies(resp);

    if (resp.statusCode != 200) {
      throw DtekApiException(
        'Не вдалося відкрити сторінку ДТЕК (${resp.statusCode})',
        statusCode: resp.statusCode,
      );
    }

    final html = resp.data as String;
    final match = RegExp(r'csrf-token"\s+content="([^"]+)"').firstMatch(html) ??
        RegExp(r"csrf-token'\s+content='([^']+)'").firstMatch(html);
    if (match == null) {
      // Possible WAF / captcha page
      if (html.contains('Incapsula') || html.contains('captcha')) {
        throw DtekApiException(
          'Сайт ДТЕК тимчасово блокує запити (WAF). Спробуйте пізніше або з іншої мережі.',
        );
      }
      throw DtekApiException('Не вдалося отримати CSRF-токен. Спробуйте пізніше.');
    }
    _csrfToken = match.group(1);
    _csrfFetchedAt = DateTime.now();
  }

  Future<Map<String, dynamic>> _postAjax(Map<String, String> fields) async {
    await _ensureSession();

    Future<Response> doPost() {
      final body = Map<String, String>.from(fields);
      body['_csrf-dtek-dnem'] = _csrfToken!;
      return _dio.post(
        _ajaxPath,
        data: body,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
          headers: {
            'Accept': 'application/json, text/javascript, */*; q=0.01',
            'X-Requested-With': 'XMLHttpRequest',
            'X-CSRF-Token': _csrfToken,
            'Origin': _baseUrl,
            'Referer': '$_baseUrl$_pagePath',
            if (_cookieHeader != null) 'Cookie': _cookieHeader,
          },
        ),
      );
    }

    var resp = await doPost();
    _captureCookies(resp);

    // CSRF / session expired → refresh and retry once
    if (resp.statusCode == 400 || resp.statusCode == 403) {
      await _ensureSession(force: true);
      resp = await doPost();
      _captureCookies(resp);
    }

    if (resp.statusCode != 200) {
      final snippet = (resp.data?.toString() ?? '').replaceAll(RegExp(r'<[^>]+>'), ' ');
      throw DtekApiException(
        'Помилка ДТЕК (${resp.statusCode}): ${snippet.trim().isEmpty ? 'невідома' : snippet.trim().substring(0, snippet.trim().length.clamp(0, 120))}',
        statusCode: resp.statusCode,
      );
    }

    final raw = resp.data;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String) {
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        throw DtekApiException('Некоректна відповідь сервера');
      }
    }
    throw DtekApiException('Некоректна відповідь сервера');
  }

  /// Returns map city -> list of streets.
  Future<Map<String, List<String>>> getStreets() async {
    final map = await _postAjax({'method': 'getStreets'});
    if (map['result'] != true) {
      throw DtekApiException('Не вдалося завантажити список вулиць');
    }
    final streets = map['streets'] as Map<String, dynamic>;
    return streets.map(
      (k, v) => MapEntry(k, (v as List<dynamic>).map((e) => e.toString()).toList()),
    );
  }

  Future<List<String>> searchCities(String query, {Map<String, List<String>>? cache}) async {
    final data = cache ?? await getStreets();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return data.keys.take(30).toList();
    return data.keys.where((c) => c.toLowerCase().contains(q)).take(40).toList();
  }

  Future<List<String>> searchStreets(
    String city,
    String query, {
    Map<String, List<String>>? cache,
  }) async {
    final data = cache ?? await getStreets();
    final streets = data[city] ?? [];
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return streets.take(40).toList();
    return streets.where((s) => s.toLowerCase().contains(q)).take(40).toList();
  }

  Future<List<String>> getHouses(String city, String street) async {
    final map = await _postAjax({
      'method': 'getHomeNum',
      'data[0][name]': 'city',
      'data[0][value]': city,
      'data[1][name]': 'street',
      'data[1][value]': street,
      'data[2][name]': 'house_num',
      'data[2][value]': '',
      'data[3][name]': 'updateFact',
      'data[3][value]': '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
    });
    if (map['result'] != true) {
      throw DtekApiException('Не вдалося завантажити номери будинків');
    }
    final data = map['data'] as Map<String, dynamic>? ?? {};
    final houses = data.keys.toList()..sort(_houseCompare);
    return houses;
  }

  int _houseCompare(String a, String b) {
    final na = int.tryParse(RegExp(r'^\d+').firstMatch(a)?.group(0) ?? '') ?? 0;
    final nb = int.tryParse(RegExp(r'^\d+').firstMatch(b)?.group(0) ?? '') ?? 0;
    if (na != nb) return na.compareTo(nb);
    return a.compareTo(b);
  }

  Future<AddressScheduleResult> fetchSchedule({
    required String city,
    required String street,
    required String house,
  }) async {
    final map = await _postAjax({
      'method': 'getHomeNum',
      'data[0][name]': 'city',
      'data[0][value]': city,
      'data[1][name]': 'street',
      'data[1][value]': street,
      'data[2][name]': 'house_num',
      'data[2][value]': house,
      'data[3][name]': 'updateFact',
      'data[3][value]': '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
    });

    if (map['result'] != true) {
      throw DtekApiException('Не вдалося отримати графік');
    }

    final updateTimestamp = map['updateTimestamp'] as String?;
    final housesData = map['data'] as Map<String, dynamic>? ?? {};
    final houseEntry = housesData[house] as Map<String, dynamic>?;

    final groups = (houseEntry?['sub_type_reason'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    final primaryGroup = groups.isNotEmpty ? groups.first : null;
    final isMultiGroup = groups.length > 1;

    final subType = (houseEntry?['sub_type'] as String?)?.trim() ?? '';
    final startDate = houseEntry?['start_date'] as String? ?? '';
    final endDate = houseEntry?['end_date'] as String? ?? '';
    final type = houseEntry?['type'] as String? ?? '';

    final reason = _buildReason(
      subType: subType,
      type: type,
      startDate: startDate,
      endDate: endDate,
      updateTimestamp: updateTimestamp,
      isMultiGroup: isMultiGroup,
      groups: groups,
    );

    final fact = map['fact'] as Map<String, dynamic>? ?? {};
    final preset = map['preset'] as Map<String, dynamic>? ?? {};
    final timeZone = (preset['time_zone'] as Map<String, dynamic>?) ?? {};

    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final tomorrowDate = todayDate.add(const Duration(days: 1));

    final today = _parseDaySchedule(
      date: todayDate,
      isToday: true,
      isTomorrow: false,
      fact: fact,
      timeZone: timeZone,
      groups: groups,
      emptyMessage: msgTodayEmpty,
    );

    final tomorrow = _parseDaySchedule(
      date: tomorrowDate,
      isToday: false,
      isTomorrow: true,
      fact: fact,
      timeZone: timeZone,
      groups: groups,
      emptyMessage: msgTomorrowEmpty,
    );

    return AddressScheduleResult(
      reason: reason,
      today: today,
      tomorrow: tomorrow,
      primaryGroup: primaryGroup,
      groups: groups,
      updateTimestamp: updateTimestamp,
    );
  }

  OutageReason _buildReason({
    required String subType,
    required String type,
    required String startDate,
    required String endDate,
    required String? updateTimestamp,
    required bool isMultiGroup,
    required List<String> groups,
  }) {
    if (subType.isNotEmpty || (type.isNotEmpty && startDate.isNotEmpty)) {
      final cause = subType.isNotEmpty
          ? subType
          : (type == '1' ? 'планові ремонтні роботи' : 'відключення');
      final buf = StringBuffer();
      buf.writeln('За вашою адресою в даний момент відсутня електроенергія');
      buf.writeln('Причина: $cause');
      if (startDate.isNotEmpty) {
        buf.writeln('Час початку – $startDate');
      }
      if (endDate.isNotEmpty) {
        buf.writeln('Орієнтовний час відновлення електроенергії – до $endDate');
      }
      return OutageReason(
        message: buf.toString().trim(),
        updateTimestamp: updateTimestamp,
        isActiveOutage: true,
        cause: cause,
        startDate: startDate,
        endDate: endDate,
        isMultiGroup: isMultiGroup,
        groups: groups,
      );
    }

    final buf = StringBuffer(msgNoBlackout);
    buf.writeln();
    buf.writeln(msgExtra);
    if (isMultiGroup) {
      buf.writeln();
      buf.writeln(msgMultiGroup);
    }

    return OutageReason(
      message: buf.toString().trim(),
      updateTimestamp: updateTimestamp,
      isActiveOutage: false,
      isMultiGroup: isMultiGroup,
      groups: groups,
    );
  }

  DaySchedule _parseDaySchedule({
    required DateTime date,
    required bool isToday,
    required bool isTomorrow,
    required Map<String, dynamic> fact,
    required Map<String, dynamic> timeZone,
    required List<String> groups,
    required String emptyMessage,
  }) {
    final factData = fact['data'];
    final factUpdate = fact['update'] as String?;
    final factTodayTs = fact['today'];

    Map<String, dynamic>? dayFactSlots;
    if (factData is Map && factData.isNotEmpty && groups.isNotEmpty) {
      final primary = groups.first;

      if (isToday && factTodayTs != null) {
        final groupMap = factData[factTodayTs.toString()] as Map<String, dynamic>?;
        dayFactSlots = groupMap?[primary] as Map<String, dynamic>?;
      }

      if (dayFactSlots == null) {
        for (final entry in factData.entries) {
          final keyTs = int.tryParse(entry.key.toString());
          if (keyTs == null) continue;
          final keyDate =
              DateTime.fromMillisecondsSinceEpoch(keyTs * 1000, isUtc: true)
                  .toLocal();
          if (keyDate.year == date.year &&
              keyDate.month == date.month &&
              keyDate.day == date.day) {
            final groupMap = entry.value as Map<String, dynamic>?;
            dayFactSlots = groupMap?[primary] as Map<String, dynamic>?;
            break;
          }
        }
      }

      if (dayFactSlots == null && isTomorrow && factData.length >= 2) {
        final todayKey = factTodayTs?.toString();
        for (final entry in factData.entries) {
          if (entry.key.toString() == todayKey) continue;
          final groupMap = entry.value as Map<String, dynamic>?;
          dayFactSlots = groupMap?[primary] as Map<String, dynamic>?;
          if (dayFactSlots != null) break;
        }
      }

      if (dayFactSlots == null && isToday && factData.length == 1) {
        final only = factData.values.first;
        if (only is Map) {
          dayFactSlots = only[primary] as Map<String, dynamic>?;
        }
      }
    }

    if (dayFactSlots != null && dayFactSlots.isNotEmpty && timeZone.isNotEmpty) {
      final slots = <TimeSlot>[];
      final sortedKeys = timeZone.keys.toList()
        ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
      for (final k in sortedKeys) {
        final tz = timeZone[k] as List<dynamic>;
        final statusStr = dayFactSlots[k]?.toString() ??
            dayFactSlots[int.tryParse(k)?.toString()]?.toString();
        slots.add(TimeSlot(
          index: int.parse(k),
          label: tz[0].toString(),
          start: tz[1].toString(),
          end: tz[2].toString(),
          status: SlotStatus.fromString(statusStr),
        ));
      }
      return DaySchedule(
        date: date,
        isToday: isToday,
        isTomorrow: isTomorrow,
        isAvailable: true,
        slots: slots,
        updatedAt: factUpdate,
      );
    }

    return DaySchedule(
      date: date,
      isToday: isToday,
      isTomorrow: isTomorrow,
      isAvailable: false,
      emptyMessage: emptyMessage,
      updatedAt: factUpdate,
    );
  }

  static String formatDateUk(DateTime d) {
    return DateFormat('dd.MM.yyyy').format(d);
  }
}
