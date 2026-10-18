import 'package:flutter/material.dart';

import '../models/address.dart';
import '../models/schedule.dart';
import '../services/dtek_api_service.dart';
import '../widgets/schedule_timeline.dart';
import '../widgets/status_banner.dart';

class AddressDetailScreen extends StatefulWidget {
  final SavedAddress address;

  const AddressDetailScreen({super.key, required this.address});

  @override
  State<AddressDetailScreen> createState() => _AddressDetailScreenState();
}

class _AddressDetailScreenState extends State<AddressDetailScreen> {
  final _api = DtekApiService();

  AddressScheduleResult? _result;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.fetchSchedule(
        city: widget.address.city,
        street: widget.address.street,
        house: widget.address.house,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = widget.address;

    return Scaffold(
      appBar: AppBar(
        title: Text(a.shortName),
        actions: [
          IconButton(
            tooltip: 'Оновити',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && _result == null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null && _result == null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 60),
                      Icon(Icons.cloud_off,
                          size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: FilledButton(
                          onPressed: _load,
                          child: const Text('Спробувати знову'),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Address header
                      Text(
                        a.displayName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_result?.primaryGroup != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Черга: ${_result!.groups.join(', ')}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      if (_result != null) ...[
                        StatusBanner(reason: _result!.reason),
                        const SizedBox(height: 16),
                        ScheduleTimeline(day: _result!.today),
                        const SizedBox(height: 12),
                        ScheduleTimeline(day: _result!.tomorrow),
                      ],

                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),
                    ],
                  ),
      ),
    );
  }
}
