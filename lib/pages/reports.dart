import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.22.85:3000/api',
  );

  String _mode = 'daily';
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _dailyReport;
  Map<String, dynamic>? _weeklyReport;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = _mode == 'daily'
          ? await http.get(Uri.parse('$_baseUrl/reports/daily'))
          : await http.get(Uri.parse('$_baseUrl/dashboard/overview?days=7'));
      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'Failed to fetch $_mode report: ${response.statusCode}';
        });
        return;
      }

      setState(() {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        if (_mode == 'daily') {
          _dailyReport = payload;
        } else {
          _weeklyReport = payload;
        }
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to fetch $_mode report: $e';
      });
    }
  }

  void _switchMode(String mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
    });
    _fetchReport();
  }

  Widget _metricCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _mode == 'daily' ? _dailyReport : _weeklyReport;
    final totals = report?['totals'] as Map<String, dynamic>? ?? {};
    final dailyTrend = report?['dailyTrend'] as List<dynamic>? ?? [];
    final weeklyCaptures = dailyTrend.fold<int>(
      0,
      (sum, item) => sum + ((item['count'] as num?)?.toInt() ?? 0),
    );

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Reports'),
        backgroundColor: Colors.black,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchReport,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Daily'),
                            selected: _mode == 'daily',
                            onSelected: (_) => _switchMode('daily'),
                            selectedColor: Colors.greenAccent.shade400,
                            labelStyle: TextStyle(
                              color:
                                  _mode == 'daily' ? Colors.black : Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Weekly'),
                            selected: _mode == 'weekly',
                            onSelected: (_) => _switchMode('weekly'),
                            selectedColor: Colors.greenAccent.shade400,
                            labelStyle: TextStyle(
                              color:
                                  _mode == 'weekly' ? Colors.black : Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _mode == 'daily'
                            ? 'Report Date: ${report?['date'] ?? 'n/a'}'
                            : 'Weekly Range: ${report?['range']?['start']?.toString().substring(0, 10) ?? 'n/a'} to ${report?['range']?['end']?.toString().substring(0, 10) ?? 'n/a'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _metricCard(
                            'Captures',
                            _mode == 'daily'
                                ? '${totals['captures'] ?? 0}'
                                : '$weeklyCaptures',
                            Colors.lightGreenAccent,
                          ),
                          const SizedBox(width: 8),
                          _metricCard(
                            'Alerts',
                            '${totals['alerts'] ?? 0}',
                            Colors.orangeAccent,
                          ),
                          const SizedBox(width: 8),
                          _metricCard(
                            _mode == 'daily' ? 'Unusual' : 'Needs Review',
                            _mode == 'daily'
                                ? '${totals['unusual'] ?? 0}'
                                : '${totals['needs_review'] ?? 0}',
                            Colors.redAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _mode == 'daily'
                              ? (report?['summary']?.toString() ??
                                  'No summary available')
                              : 'Weekly Overview\n'
                                  'Total Captures: $weeklyCaptures\n'
                                  'Alerts: ${totals['alerts'] ?? 0}\n'
                                  'Approved: ${totals['approved'] ?? 0}\n'
                                  'Needs Review: ${totals['needs_review'] ?? 0}\n'
                                  'Discarded: ${totals['discard'] ?? 0}',
                          style: const TextStyle(color: Colors.white, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
