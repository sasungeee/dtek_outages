import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/address.dart';

class StorageService {
  static const _fileName = 'saved_addresses_v1.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<List<SavedAddress>> loadAddresses() async {
    try {
      final file = await _file();
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      final addresses = list
          .map((e) => SavedAddress.fromJson(e as Map<String, dynamic>))
          .toList();
      addresses.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.addedAt.compareTo(a.addedAt);
      });
      return addresses;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAddresses(List<SavedAddress> addresses) async {
    final file = await _file();
    final encoded = jsonEncode(addresses.map((a) => a.toJson()).toList());
    await file.writeAsString(encoded, flush: true);
  }

  Future<void> addAddress(SavedAddress address) async {
    final list = await loadAddresses();
    final exists = list.any((a) =>
        a.city == address.city &&
        a.street == address.street &&
        a.house == address.house);
    if (exists) return;
    list.add(address);
    await saveAddresses(list);
  }

  Future<void> removeAddress(String id) async {
    final list = await loadAddresses();
    list.removeWhere((a) => a.id == id);
    await saveAddresses(list);
  }

  Future<void> setPinned(String id, {bool pinned = true}) async {
    final list = await loadAddresses();
    final updated = list.map((a) {
      if (a.id == id) return a.copyWith(isPinned: pinned);
      if (pinned && a.isPinned) return a.copyWith(isPinned: false);
      return a;
    }).toList();
    await saveAddresses(updated);
  }

  Future<void> updateAddress(SavedAddress address) async {
    final list = await loadAddresses();
    final idx = list.indexWhere((a) => a.id == address.id);
    if (idx >= 0) {
      list[idx] = address;
      await saveAddresses(list);
    }
  }
}
