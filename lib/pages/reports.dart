import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.wildpulse.ink/api',
  );

  String _mode = 'daily';
  DateTime _selectedDate = DateTime.now();

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _report;

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
      final date = _selectedDate.toIso8601String().substring(0, 10);
      final month = date.substring(0, 7);
      final year = _selectedDate.year;

      late http.Response response;

      if (_mode == 'daily') {
        response = await http.get(
          Uri.parse('$_baseUrl/reports/daily?date=$date'),
        );
      } else if (_mode == 'weekly') {
        response = await http.get(
          Uri.parse('$_baseUrl/dashboard/overview?days=7'),
        );
      } else if (_mode == 'monthly') {
        response = await http.get(
          Uri.parse('$_baseUrl/reports/monthly?month=$month'),
        );
      } else {
        response = await http.get(
          Uri.parse('$_baseUrl/reports/yearly?year=$year'),
        );
      }

      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'Failed to fetch $_mode report (${response.statusCode})';
        });
        return;
      }

      final payload = jsonDecode(response.body);

      setState(() {
        _report = payload;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });

      _fetchReport();
    }
  }

  Widget _metricCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trendChart(List<dynamic> trend) {
    if (trend.isEmpty) {
      return const Text(
        "No trend data available",
        style: TextStyle(color: Colors.white70),
      );
    }

    final spots =
        trend.asMap().entries.map((e) {
          final count = (e.value['count'] as num?)?.toDouble() ?? 0;
          return FlSpot(e.key.toDouble(), count);
        }).toList();

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 3,
              color: Colors.greenAccent,
              dotData: FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totals = _report?['totals'] ?? {};
    final trend = _report?['dailyTrend'] ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('WildPulse Reports'),
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false,
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              )
              : RefreshIndicator(
                onRefresh: _fetchReport,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 10,
                      children: [
                        ChoiceChip(
                          label: const Text('Daily'),
                          selected: _mode == 'daily',
                          onSelected: (_) => _switchMode('daily'),
                        ),
                        ChoiceChip(
                          label: const Text('Weekly'),
                          selected: _mode == 'weekly',
                          onSelected: (_) => _switchMode('weekly'),
                        ),
                        ChoiceChip(
                          label: const Text('Monthly'),
                          selected: _mode == 'monthly',
                          onSelected: (_) => _switchMode('monthly'),
                        ),
                        ChoiceChip(
                          label: const Text('Yearly'),
                          selected: _mode == 'yearly',
                          onSelected: (_) => _switchMode('yearly'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Date: ${_selectedDate.toString().substring(0, 10)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.calendar_month),
                          label: const Text("Pick Date"),
                          onPressed: _pickDate,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        _metricCard(
                          "Captures",
                          "${totals['captures'] ?? 0}",
                          Colors.lightGreenAccent,
                        ),
                        const SizedBox(width: 8),
                        _metricCard(
                          "Alerts",
                          "${totals['alerts'] ?? 0}",
                          Colors.orangeAccent,
                        ),
                        const SizedBox(width: 8),
                        _metricCard(
                          "Needs Review",
                          "${totals['needs_review'] ?? 0}",
                          Colors.redAccent,
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    const Text(
                      "Capture Trend",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _trendChart(trend),
                    ),

                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _report?['summary'] ?? "No summary available",
                        style: const TextStyle(
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
