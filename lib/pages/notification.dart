import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../core/app_api.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<Map<String, dynamic>> _items = [];
  final Set<String> _actionLoadingIds = {};
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;
  final String _sortBy = 'createdAt';
  final String _order = 'desc';

  @override
  void initState() {
    super.initState();
    _fetchNeedsReview();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _fetchNeedsReview(),
    );
  }

  Future<void> _fetchNeedsReview() async {
    try {
      final params = AppApi.reportQuery({
        'limit': '100',
        'sortBy': _sortBy,
        'order': _order,
      });

      final response = await AppApi.getAdmin(
        '/needs-review',
        queryParameters: params,
      );
      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          _error =
              response.statusCode == 401
                  ? 'Admin session expired. Log in again.'
                  : 'Failed to fetch review queue: ${response.statusCode}';
          _loading = false;
        });
        return;
      }

      final List<dynamic> data = jsonDecode(response.body);
      final mapped =
          data.map<Map<String, dynamic>>((item) {
            return {
              'id': item['id'] as String? ?? '',
              'url': item['url'] as String? ?? '',
              'species': item['species'] as String? ?? 'unknown',
              'confidence': (item['confidence'] as num?)?.toDouble() ?? 0,
              'riskScore': (item['riskScore'] as num?)?.toInt() ?? 0,
              'priority': item['priority'] as String? ?? 'low',
              'capturedAt':
                  (item['capturedAt'] ?? item['createdAt']) as String?,
              'zoneId': item['zoneId'] as String?,
              'aiSummary': item['aiSummary'] as String?,
              'status': item['status'] as String? ?? 'needs_review',
              'riskReasons':
                  (item['riskReasons'] as List<dynamic>? ?? [])
                      .map((e) => e.toString())
                      .toList(),
            };
          }).toList();

      setState(() {
        _items = mapped;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to fetch review queue: $e';
        _loading = false;
      });
    }
  }

  Future<void> _takeAction(String id, String action) async {
    setState(() {
      _actionLoadingIds.add(id);
    });

    try {
      final response = await AppApi.patchAdmin(
        '/needs-review/$id/action',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': action}),
      );

      if (!mounted) return;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        setState(() {
          _error =
              response.statusCode == 401
                  ? 'Admin session expired. Log in again.'
                  : 'Failed to $action item: ${response.statusCode}';
        });
        return;
      }

      await _fetchNeedsReview();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to $action item: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _actionLoadingIds.remove(id);
        });
      }
    }
  }

  void _openFullView(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (context) {
        return Scaffold(
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
        );
      },
    );
  }

  String _formatCapturedTime(String? isoTime) {
    if (isoTime == null || isoTime.isEmpty) return 'Unknown time';
    try {
      final dateTime = DateTime.parse(isoTime).toLocal();
      final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '${dateTime.month}/${dateTime.day}/${dateTime.year} $hour:$minute $period';
    } catch (_) {
      return 'Unknown time';
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF222222),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Needs Review',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Container(
            margin: const EdgeInsets.only(left: 8, right: 150),
            height: 3,
            color: Colors.lightGreenAccent,
          ),
        ),
      ),
      body:
          _loading
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
                onRefresh: _fetchNeedsReview,
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (_items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 140),
                        child: Center(
                          child: Text(
                            'No items need review',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      )
                    else
                      ..._items.map((item) {
                        final id = item['id'] as String;
                        final confidence = ((item['confidence'] as double) *
                                100)
                            .toStringAsFixed(1);
                        final reasons = (item['riskReasons'] as List<String>)
                            .join(', ');
                        final isActionLoading = _actionLoadingIds.contains(id);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: GestureDetector(
                                  onTap:
                                      () =>
                                          _openFullView(item['url'] as String),
                                  child: Image.network(
                                    item['url'] as String,
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) => Container(
                                          height: 180,
                                          color: Colors.grey[800],
                                          child: const Icon(
                                            Icons.broken_image,
                                            color: Colors.white70,
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${(item['species'] as String).toUpperCase()}  •  $confidence%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Status: ${item['status']} • Risk ${item['riskScore']} • ${item['priority']}',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Time: ${_formatCapturedTime(item['capturedAt'] as String?)}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              if ((item['zoneId'] as String?) != null)
                                Text(
                                  'Zone: ${item['zoneId']}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              if (reasons.isNotEmpty)
                                Text(
                                  'Reasons: $reasons',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                              if ((item['aiSummary'] as String?)
                                      ?.trim()
                                      .isNotEmpty ??
                                  false) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    item['aiSummary'] as String,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed:
                                          isActionLoading
                                              ? null
                                              : () =>
                                                  _takeAction(id, 'approve'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green[700],
                                      ),
                                      child: const Text('Approve'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed:
                                          isActionLoading
                                              ? null
                                              : () =>
                                                  _takeAction(id, 'discard'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red[700],
                                      ),
                                      child: const Text('Discard'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed:
                                          isActionLoading
                                              ? null
                                              : () =>
                                                  _takeAction(id, 'escalate'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange[700],
                                      ),
                                      child:
                                          isActionLoading
                                              ? const SizedBox(
                                                height: 16,
                                                width: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                              : const Text('Escalate'),
                                    ),
                                  ),
                                ],
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
