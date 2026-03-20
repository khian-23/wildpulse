import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../core/app_api.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _mode = 'daily';
  DateTime _selectedDate = DateTime.now();
  bool _hasUserPickedDate = false;

  bool _loading = true;
  String? _error;
  String? _emptyMessage;

  Map<String, dynamic>? _report;
  List<Map<String, dynamic>> _images = [];
  bool _imagesLoading = false;
  String? _imagesError;
  final Set<String> _downloadLoadingKeys = {};

  Map<String, dynamic> _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asStringMapList(dynamic value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }

    return value.map<Map<String, dynamic>>((item) {
      if (item is Map<String, dynamic>) {
        return item;
      }
      if (item is Map) {
        return item.map((key, val) => MapEntry(key.toString(), val));
      }
      return <String, dynamic>{};
    }).toList();
  }

  String get _modeLabel {
    switch (_mode) {
      case 'daily':
        return 'daily';
      case 'weekly':
        return 'weekly';
      case 'monthly':
        return 'monthly';
      case 'yearly':
        return 'yearly';
      default:
        return 'report';
    }
  }

  String _buildHttpErrorMessage(int statusCode) {
    if (statusCode == 401) {
      return 'Admin session expired or invalid. Log in again.';
    }
    if (statusCode == 404) {
      return 'The $_modeLabel report endpoint is not available on the deployed backend yet.';
    }
    if (statusCode >= 500) {
      return 'The backend failed while generating the $_modeLabel report.';
    }

    return 'Failed to fetch $_modeLabel report ($statusCode).';
  }

  bool _hasReportData(Map<String, dynamic>? report) {
    if (report == null) return false;

    final totals = _asStringMap(report['totals']);
    if (totals.isNotEmpty) {
      final captures = totals['captures'];
      if (captures is num && captures > 0) {
        return true;
      }
    }

    final trend = _asStringMapList(
      report['dailyTrend'] ??
          report['daily_breakdown'] ??
          report['monthly_breakdown'],
    );
    return trend.isNotEmpty;
  }

  Map<String, DateTime> _reportRange() {
    final base = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    switch (_mode) {
      case 'weekly':
        return {
          'start': base.subtract(const Duration(days: 6)),
          'end': base.add(const Duration(days: 1)),
        };
      case 'monthly':
        return {
          'start': DateTime(_selectedDate.year, _selectedDate.month, 1),
          'end': DateTime(_selectedDate.year, _selectedDate.month + 1, 1),
        };
      case 'yearly':
        return {
          'start': DateTime(_selectedDate.year, 1, 1),
          'end': DateTime(_selectedDate.year + 1, 1, 1),
        };
      default:
        return {
          'start': base,
          'end': base.add(const Duration(days: 1)),
        };
    }
  }

  String _formatCapturedTime(String? isoTime) {
    if (isoTime == null || isoTime.isEmpty) return 'Unknown time';
    try {
      final dateTime = DateTime.parse(isoTime).toLocal();
      final month = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][dateTime.month - 1];
      final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '$month ${dateTime.day}, ${dateTime.year} • $hour:$minute $period';
    } catch (_) {
      return 'Unknown time';
    }
  }

  void _openFullView(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                automaticallyImplyLeading: false,
                backgroundColor: Colors.black,
                elevation: 0,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              body: Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder:
                        (_, __, ___) => const Icon(
                          Icons.broken_image,
                          color: Colors.white70,
                          size: 56,
                        ),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  Future<void> _downloadImage(String key, String imageUrl) async {
    setState(() {
      _downloadLoadingKeys.add(key);
    });

    try {
      if (kIsWeb) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Web app: open image in a new tab then use browser Save image.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final response = await http.get(Uri.parse(imageUrl));
      if (!mounted) return;

      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download image: ${response.statusCode}'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final filename = 'wildpulse_${DateTime.now().millisecondsSinceEpoch}.jpg';
      File file;
      try {
        if (Platform.isAndroid) {
          final downloadDir = await getExternalStorageDirectory();
          final baseDir =
              downloadDir ?? await getApplicationDocumentsDirectory();
          if (!await baseDir.exists()) {
            await baseDir.create(recursive: true);
          }
          file = File('${baseDir.path}/$filename');
        } else {
          final dir =
              await getDownloadsDirectory() ??
              await getApplicationDocumentsDirectory();
          file = File('${dir.path}/$filename');
        }
        await file.writeAsBytes(response.bodyBytes);
      } catch (_) {
        final dir = await getApplicationDocumentsDirectory();
        file = File('${dir.path}/$filename');
        await file.writeAsBytes(response.bodyBytes);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded: ${file.path}'),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download image: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadLoadingKeys.remove(key);
        });
      }
    }
  }

  Future<void> _fetchImagesForRange() async {
    setState(() {
      _imagesLoading = true;
      _imagesError = null;
      _images = [];
    });

    final range = _reportRange();
    final startIso = range['start']!.toUtc().toIso8601String();
    final endIso = range['end']!.toUtc().toIso8601String();

    try {
      final response = await AppApi.getAdmin(
        '/images',
        queryParameters: AppApi.reportQuery({
          'limit': '30',
          'startDate': startIso,
          'endDate': endIso,
        }),
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          _imagesLoading = false;
          _imagesError =
              response.statusCode == 401
                  ? 'Admin session expired. Log in again.'
                  : 'Failed to load images: ${response.statusCode}';
        });
        return;
      }

      final List data = jsonDecode(response.body) as List;
      final images =
          data.map<Map<String, dynamic>>((item) {
            return Map<String, dynamic>.from(item as Map);
          }).toList();

      setState(() {
        _images = images;
        _imagesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _imagesLoading = false;
        _imagesError = 'Failed to load images: $e';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() {
      _loading = true;
      _error = null;
      _emptyMessage = null;
    });

    try {
      final date = _selectedDate.toIso8601String().substring(0, 10);
      final month = date.substring(0, 7);
      final year = _selectedDate.year;

      late final dynamic response;
      final query = AppApi.reportQuery();

      if (_mode == 'daily') {
        response = await AppApi.getAdmin(
          '/reports/daily',
          queryParameters: {...query, 'date': date},
        );
      } else if (_mode == 'weekly') {
        response = await AppApi.getAdmin(
          '/dashboard/overview',
          queryParameters: {...query, 'days': '7'},
        );
      } else if (_mode == 'monthly') {
        response = await AppApi.getAdmin(
          '/reports/monthly',
          queryParameters: {...query, 'month': month},
        );
      } else {
        response = await AppApi.getAdmin(
          '/reports/yearly',
          queryParameters: {...query, 'year': '$year'},
        );
      }

      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = _buildHttpErrorMessage(response.statusCode);
        });
        return;
      }

      final payload = _asStringMap(jsonDecode(response.body));

      setState(() {
        _report = payload;
        _loading = false;
        if (!_hasReportData(payload)) {
          final dateLabel = _selectedDate.toString().substring(0, 10);
          _emptyMessage =
              _hasUserPickedDate
                  ? 'No $_modeLabel report data is available for $dateLabel.'
                  : 'No $_modeLabel report data is available yet for today.';
        }
      });
      await _fetchImagesForRange();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
            'Unable to reach the backend. Check your connection and API settings.';
      });
    }
  }

  void _switchMode(String mode) {
    if (_mode == mode) return;

    setState(() {
      _mode = mode;
      _hasUserPickedDate = false;
      _selectedDate = DateTime.now();
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
          _hasUserPickedDate = true;
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

  String _chartTitle() {
    switch (_mode) {
      case 'weekly':
        return 'Captures Over The Last 7 Days';
      case 'monthly':
        return 'Captures Per Day This Month';
      case 'yearly':
        return 'Captures Per Month This Year';
      default:
        return 'Capture Trend';
    }
  }

  String _xAxisLabel(Map<String, dynamic> item) {
    if (_mode == 'yearly') {
      final value = item['month']?.toString() ?? '';
      if (value.length >= 7) {
        return value.substring(5, 7);
      }
      return value;
    }

    final value = (item['day'] ?? item['month'])?.toString() ?? '';
    if (value.length >= 10) {
      return value.substring(8, 10);
    }
    if (value.length >= 7) {
      return value.substring(5, 7);
    }
    return value;
  }

  double _maxTrendCount(List<Map<String, dynamic>> trend) {
    if (trend.isEmpty) return 1;

    final maxValue = trend
        .map((item) => (item['count'] as num?)?.toDouble() ?? 0)
        .fold<double>(0, (max, value) => value > max ? value : max);

    return maxValue <= 0 ? 1 : maxValue;
  }

  SideTitles _bottomTitles(List<Map<String, dynamic>> trend) {
    return SideTitles(
      showTitles: true,
      reservedSize: 28,
      interval: 1,
      getTitlesWidget: (value, meta) {
        final index = value.toInt();
        if (index < 0 || index >= trend.length) {
          return const SizedBox.shrink();
        }

        final skipFactor =
            trend.length > 16
                ? 3
                : trend.length > 10
                ? 2
                : 1;
        if (index % skipFactor != 0) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _xAxisLabel(trend[index]),
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        );
      },
    );
  }

  SideTitles _leftTitles(double maxY) {
    return SideTitles(
      showTitles: true,
      reservedSize: 28,
      interval: maxY <= 4 ? 1 : (maxY / 4).ceilToDouble(),
      getTitlesWidget: (value, meta) {
        return Text(
          value.toInt().toString(),
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        );
      },
    );
  }

  Widget _trendChart(List<Map<String, dynamic>> trend) {
    if (trend.isEmpty) {
      return const Text(
        "No trend data available",
        style: TextStyle(color: Colors.white70),
      );
    }

    final maxY = _maxTrendCount(trend);

    if (_mode == 'monthly' || _mode == 'yearly') {
      final bars =
          trend.asMap().entries.map((entry) {
            final count = (entry.value['count'] as num?)?.toDouble() ?? 0;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: count,
                  width: trend.length > 20 ? 8 : 12,
                  borderRadius: BorderRadius.circular(4),
                  color:
                      _mode == 'yearly'
                          ? Colors.amberAccent
                          : Colors.lightGreenAccent,
                ),
              ],
            );
          }).toList();

      return SizedBox(
        height: 240,
        child: BarChart(
          BarChartData(
            maxY: maxY * 1.2,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine:
                  (_) => FlLine(color: Colors.white10, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(sideTitles: _bottomTitles(trend)),
              leftTitles: AxisTitles(sideTitles: _leftTitles(maxY)),
            ),
            barGroups: bars,
          ),
        ),
      );
    }

    final spots =
        trend.asMap().entries.map((e) {
          final count = (e.value['count'] as num?)?.toDouble() ?? 0;
          return FlSpot(e.key.toDouble(), count);
        }).toList();

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine:
                (_) => FlLine(color: Colors.white10, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(sideTitles: _bottomTitles(trend)),
            leftTitles: AxisTitles(sideTitles: _leftTitles(maxY)),
          ),
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

  Widget _emptyStateCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _emptyMessage ?? 'No report data available.',
        style: const TextStyle(color: Colors.white70, height: 1.4),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _buildSummary(
    Map<String, dynamic> report,
    Map<String, dynamic> totals,
    int needsReviewCount,
  ) {
    final backendSummary = (report['summary']?.toString() ?? '').trim();
    if (backendSummary != null && backendSummary.isNotEmpty) {
      return backendSummary;
    }

    if (_mode == 'weekly') {
      final captures = totals['captures'] ?? 0;
      final alerts = totals['alerts'] ?? 0;
      final approved = totals['approved'] ?? 0;
      final topSpecies = _asStringMapList(report['topSpecies']);
      final topSpeciesName =
          topSpecies.isNotEmpty
              ? (topSpecies.first['species']?.toString() ?? 'unknown')
              : 'none';

      return 'Weekly Wildlife Report\n'
          'Total Captures: $captures\n'
          'Alerts Triggered: $alerts\n'
          'Needs Review: $needsReviewCount\n'
          'Approved: $approved\n'
          'Top Species: $topSpeciesName';
    }

    return 'No summary available';
  }

  @override
  Widget build(BuildContext context) {
    final report = _asStringMap(_report);
    final totals = _asStringMap(report['totals']);
    final statuses = _asStringMapList(report['statuses']);
    final trend = _asStringMapList(
      report['dailyTrend'] ??
          report['daily_breakdown'] ??
          report['monthly_breakdown'],
    );
    final needsReviewCount =
        totals['needs_review'] ??
        statuses
            .where((item) => item['status'] == 'needs_review')
            .map((item) => (item['count'] as num?)?.toInt() ?? 0)
            .fold<int>(0, (sum, count) => sum + count);
    final summary = _buildSummary(report, totals, needsReviewCount);

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
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
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

                    if (_emptyMessage != null) ...[
                      _emptyStateCard(),
                    ] else ...[
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
                            "$needsReviewCount",
                            Colors.redAccent,
                          ),
                        ],
                      ),

                      const SizedBox(height: 25),

                      Text(
                        _chartTitle(),
                        style: const TextStyle(
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
                          summary,
                          style: const TextStyle(
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'Captured Images',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_imagesLoading)
                      const LinearProgressIndicator()
                    else if (_imagesError != null)
                      Text(
                        _imagesError!,
                        style: const TextStyle(color: Colors.redAccent),
                      )
                    else if (_images.isEmpty)
                      const Text(
                        'No captures found for this period.',
                        style: TextStyle(color: Colors.white70),
                      )
                    else
                      ..._images.map((item) {
                        final imageUrl = item['url']?.toString() ?? '';
                        final species = item['species']?.toString() ?? 'unknown';
                        final capturedAt = item['capturedAt']?.toString();
                        final confidence =
                            (item['confidence'] as num?)?.toDouble();
                        final downloadKey =
                            capturedAt ?? imageUrl;
                        final isDownloading = _downloadLoadingKeys.contains(
                          downloadKey,
                        );

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              if (imageUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: GestureDetector(
                                    onTap: () => _openFullView(imageUrl),
                                    child: Image.network(
                                      imageUrl,
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (_, __, ___) => Container(
                                            width: 70,
                                            height: 70,
                                            color: Colors.black26,
                                            child: const Icon(
                                              Icons.broken_image,
                                              color: Colors.white54,
                                            ),
                                          ),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.photo,
                                    color: Colors.white54,
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      species.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatCapturedTime(capturedAt),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (confidence != null)
                                      Text(
                                        'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        IconButton(
                                          tooltip: 'Full view',
                                          icon: const Icon(
                                            Icons.fullscreen,
                                            color: Colors.white70,
                                          ),
                                          onPressed:
                                              imageUrl.isEmpty
                                                  ? null
                                                  : () => _openFullView(imageUrl),
                                        ),
                                        const SizedBox(width: 6),
                                        SizedBox(
                                          height: 32,
                                          child: ElevatedButton(
                                            onPressed:
                                                imageUrl.isEmpty ||
                                                        isDownloading
                                                    ? null
                                                    : () => _downloadImage(
                                                      downloadKey,
                                                      imageUrl,
                                                    ),
                                            child:
                                                isDownloading
                                                    ? const SizedBox(
                                                      height: 14,
                                                      width: 14,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Colors.white,
                                                          ),
                                                    )
                                                    : const Text('Download'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
    );
  }
}
