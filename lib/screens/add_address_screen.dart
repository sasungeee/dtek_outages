import 'package:flutter/material.dart';

import '../models/address.dart';
import '../services/dtek_api_service.dart';
import '../services/storage_service.dart';

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _api = DtekApiService();
  final _storage = StorageService();

  Map<String, List<String>>? _streetsCache;
  bool _loadingCache = true;
  String? _cacheError;

  String? _city;
  String? _street;
  String? _house;

  List<String> _citySuggestions = [];
  List<String> _streetSuggestions = [];
  List<String> _houseSuggestions = [];

  bool _loadingHouses = false;
  bool _saving = false;

  final _cityCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _houseCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStreetsCache();
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _streetCtrl.dispose();
    _houseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStreetsCache() async {
    setState(() {
      _loadingCache = true;
      _cacheError = null;
    });
    try {
      final data = await _api.getStreets();
      if (!mounted) return;
      setState(() {
        _streetsCache = data;
        _loadingCache = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCache = false;
        _cacheError = e.toString();
      });
    }
  }

  void _onCityChanged(String q) {
    if (_streetsCache == null) return;
    final list = _streetsCache!.keys
        .where((c) => c.toLowerCase().contains(q.trim().toLowerCase()))
        .take(40)
        .toList();
    setState(() {
      _citySuggestions = list;
      if (_city != null && _city != q) {
        _city = null;
        _street = null;
        _house = null;
        _streetCtrl.clear();
        _houseCtrl.clear();
        _streetSuggestions = [];
        _houseSuggestions = [];
      }
    });
  }

  void _selectCity(String city) {
    setState(() {
      _city = city;
      _cityCtrl.text = city;
      _citySuggestions = [];
      _street = null;
      _house = null;
      _streetCtrl.clear();
      _houseCtrl.clear();
      _streetSuggestions = [];
      _houseSuggestions = [];
    });
  }

  void _onStreetChanged(String q) {
    if (_city == null || _streetsCache == null) return;
    final streets = _streetsCache![_city!] ?? [];
    final list = streets
        .where((s) => s.toLowerCase().contains(q.trim().toLowerCase()))
        .take(40)
        .toList();
    setState(() {
      _streetSuggestions = list;
      if (_street != null && _street != q) {
        _street = null;
        _house = null;
        _houseCtrl.clear();
        _houseSuggestions = [];
      }
    });
  }

  Future<void> _selectStreet(String street) async {
    setState(() {
      _street = street;
      _streetCtrl.text = street;
      _streetSuggestions = [];
      _house = null;
      _houseCtrl.clear();
      _houseSuggestions = [];
      _loadingHouses = true;
    });
    try {
      final houses = await _api.getHouses(_city!, street);
      if (!mounted) return;
      setState(() {
        _houseSuggestions = houses;
        _loadingHouses = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingHouses = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка завантаження будинків: $e')),
      );
    }
  }

  void _onHouseChanged(String q) {
    // filter already loaded list
    if (_street == null) return;
    // keep full list in _houseSuggestions as master; filter locally
  }

  void _selectHouse(String house) {
    setState(() {
      _house = house;
      _houseCtrl.text = house;
    });
  }

  Future<void> _save() async {
    if (_city == null || _street == null || _house == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Оберіть місто, вулицю та будинок')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      // Fetch once to resolve group
      final result = await _api.fetchSchedule(
        city: _city!,
        street: _street!,
        house: _house!,
      );
      final address = SavedAddress(
        city: _city!,
        street: _street!,
        house: _house!,
        group: result.primaryGroup,
        groups: result.groups,
      );
      await _storage.addAddress(address);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка збереження: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Додати адресу'),
      ),
      body: _loadingCache
          ? const Center(child: CircularProgressIndicator())
          : _cacheError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_cacheError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadStreetsCache,
                          child: const Text('Повторити'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Введіть адресу українською, як на сайті ДТЕК',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // City
                    TextField(
                      controller: _cityCtrl,
                      decoration: InputDecoration(
                        labelText: 'Населений пункт',
                        hintText: 'Почніть вводити…',
                        prefixIcon: const Icon(Icons.location_city),
                        border: const OutlineInputBorder(),
                        suffixIcon: _city != null
                            ? Icon(Icons.check_circle,
                                color: theme.colorScheme.primary)
                            : null,
                      ),
                      onChanged: _onCityChanged,
                    ),
                    if (_citySuggestions.isNotEmpty)
                      _SuggestionList(
                        items: _citySuggestions,
                        onSelect: _selectCity,
                      ),

                    const SizedBox(height: 16),

                    // Street
                    TextField(
                      controller: _streetCtrl,
                      enabled: _city != null,
                      decoration: InputDecoration(
                        labelText: 'Вулиця',
                        hintText: 'Почніть вводити…',
                        prefixIcon: const Icon(Icons.signpost_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: _street != null
                            ? Icon(Icons.check_circle,
                                color: theme.colorScheme.primary)
                            : null,
                      ),
                      onChanged: _onStreetChanged,
                    ),
                    if (_streetSuggestions.isNotEmpty)
                      _SuggestionList(
                        items: _streetSuggestions,
                        onSelect: _selectStreet,
                      ),

                    const SizedBox(height: 16),

                    // House
                    TextField(
                      controller: _houseCtrl,
                      enabled: _street != null && !_loadingHouses,
                      decoration: InputDecoration(
                        labelText: 'Номер будинку',
                        hintText: _loadingHouses
                            ? 'Завантаження…'
                            : 'Оберіть або введіть',
                        prefixIcon: const Icon(Icons.home_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: _loadingHouses
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : _house != null
                                ? Icon(Icons.check_circle,
                                    color: theme.colorScheme.primary)
                                : null,
                      ),
                      onChanged: (q) {
                        setState(() {
                          _house = null;
                        });
                      },
                    ),
                    if (!_loadingHouses &&
                        _street != null &&
                        _houseSuggestions.isNotEmpty)
                      _SuggestionList(
                        items: _houseSuggestions
                            .where((h) => h
                                .toLowerCase()
                                .contains(_houseCtrl.text.trim().toLowerCase()))
                            .take(40)
                            .toList(),
                        onSelect: _selectHouse,
                      ),

                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: _saving ||
                              _city == null ||
                              _street == null ||
                              (_house == null && _houseCtrl.text.trim().isEmpty)
                          ? null
                          : () {
                              if (_house == null &&
                                  _houseCtrl.text.trim().isNotEmpty) {
                                _house = _houseCtrl.text.trim();
                              }
                              _save();
                            },
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Збереження…' : 'Зберегти адресу'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  final List<String> items;
  final ValueChanged<String> onSelect;

  const _SuggestionList({required this.items, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 4),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          return ListTile(
            dense: true,
            title: Text(items[i], style: const TextStyle(fontSize: 14)),
            onTap: () => onSelect(items[i]),
          );
        },
      ),
    );
  }
}
