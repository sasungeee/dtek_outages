import 'package:flutter/material.dart';

import '../models/address.dart';
import '../services/storage_service.dart';
import 'add_address_screen.dart';
import 'address_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService();
  List<SavedAddress> _addresses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final list = await _storage.loadAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _addresses = [];
        _loading = false;
      });
    }
  }

  Future<void> _openAdd() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddAddressScreen()),
    );
    if (added == true) await _reload();
  }

  Future<void> _openDetail(SavedAddress address) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddressDetailScreen(address: address),
      ),
    );
  }

  Future<void> _togglePin(SavedAddress address) async {
    await _storage.setPinned(address.id, pinned: !address.isPinned);
    await _reload();
  }

  Future<void> _delete(SavedAddress address) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Видалити адресу?'),
        content: Text(address.displayName),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Видалити'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _storage.removeAddress(address.id);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ДТЕК · Відключення'),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        icon: const Icon(Icons.add),
        label: const Text('Адреса'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bolt_outlined,
                          size: 64,
                          color: theme.colorScheme.primary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Немає збережених адрес',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Додайте адресу, щоб бачити графік відключень на сьогодні та завтра',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _openAdd,
                          icon: const Icon(Icons.add),
                          label: const Text('Додати адресу'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                  itemCount: _addresses.length,
                  itemBuilder: (context, i) {
                    final a = _addresses[i];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: a.isPinned
                          ? theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.35)
                          : theme.colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: a.isPinned
                            ? BorderSide(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.4),
                              )
                            : BorderSide.none,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: a.isPinned
                              ? theme.colorScheme.primary
                              : theme.colorScheme.secondaryContainer,
                          child: Icon(
                            a.isPinned ? Icons.push_pin : Icons.home_outlined,
                            color: a.isPinned
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSecondaryContainer,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          a.shortName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          [
                            a.city,
                            if (a.group != null) 'Черга ${a.group}',
                          ].join(' · '),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'pin') _togglePin(a);
                            if (v == 'delete') _delete(a);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'pin',
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  a.isPinned
                                      ? Icons.push_pin_outlined
                                      : Icons.push_pin,
                                ),
                                title: Text(
                                  a.isPinned
                                      ? 'Відкріпити'
                                      : 'Закріпити основною',
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                dense: true,
                                leading: Icon(Icons.delete_outline),
                                title: Text('Видалити'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _openDetail(a),
                      ),
                    );
                  },
                ),
    );
  }
}
