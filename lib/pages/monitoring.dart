import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class MonitoringFeedPage extends StatefulWidget {
  const MonitoringFeedPage({super.key});

  @override
  State<MonitoringFeedPage> createState() => _MonitoringFeedPageState();
}

class _MonitoringFeedPageState extends State<MonitoringFeedPage> {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.wildpulse.ink/api',
  );

  List<Map<String, dynamic>> feedItems = [];
  bool isLoading = true;
  String? errorMessage;
  Timer? _pollTimer;
  final TextEditingController _deviceIdController =
      TextEditingController(text: 'pi-001');
  bool _commandLoading = false;
  final Set<String> _downloadLoadingKeys = {};

  @override
  void initState() {
    super.initState();
    _fetchFeedItems(showLoader: true);
    _pollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _fetchFeedItems(showLoader: false),
    );
  }

  Future<void> _fetchFeedItems({required bool showLoader}) async {
    if (showLoader && mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final response = await http.get(Uri.parse('$_baseUrl/images?limit=100'));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          feedItems = data.map<Map<String, dynamic>>((item) {
            return {
              'image': item['url'] as String? ?? '',
              'capturedOn': (item['capturedAt'] ?? item['createdAt']) as String?,
              'species': item['species'] as String? ?? 'unknown',
              'confidence': (item['confidence'] as num?)?.toDouble() ?? 0,
              'aiSummary': item['aiSummary'] as String?,
              'riskScore': (item['riskScore'] as num?)?.toInt() ?? 0,
              'priority': item['priority'] as String? ?? 'low',
            };
          }).toList();
          isLoading = false;
          errorMessage = null;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to fetch images: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Failed to fetch images: $e';
        isLoading = false;
      });
    }
  }

  String _formatCapturedTime(String? isoTime) {
    if (isoTime == null || isoTime.isEmpty) return 'Unknown time';
    try {
      final dateTime = DateTime.parse(isoTime).toLocal();
      return '${_formatDate(dateTime)} at ${_formatTime(dateTime)}';
    } catch (_) {
      return 'Unknown time';
    }
  }

  String _formatDate(DateTime dateTime) {
    return '${_monthName(dateTime.month)} ${dateTime.day}, ${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _monthName(int month) {
    const months = [
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
    ];
    return months[month - 1];
  }

  Future<void> _sendPiCommand(String command) async {
    final deviceId = _deviceIdController.text.trim();
    if (deviceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device ID is required'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _commandLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/pi/$deviceId/commands'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'command': command,
          'payload': {'source': 'flutter_monitoring'},
        }),
      );

      if (!mounted) return;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send command: ${response.statusCode}'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Command sent: $command ($deviceId)'),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send command: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _commandLoading = false;
        });
      }
    }
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
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }
          file = File('${downloadDir.path}/$filename');
        } else {
          final dir = await getApplicationDocumentsDirectory();
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

  void _openFullView(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
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
                errorBuilder: (_, __, ___) => const Icon(
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

  void _openLiveControlSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Capture Controls',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _deviceIdController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Device ID (e.g. pi-001)',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black54,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _commandLoading
                      ? null
                      : () => _sendPiCommand('capture_now'),
                  icon: const Icon(Icons.camera_alt),
                  label: Text(_commandLoading ? 'Sending...' : 'Capture Now'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _deviceIdController.dispose();
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
          'Monitoring Feed',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openLiveControlSheet,
            icon: const Icon(Icons.videocam_outlined),
            tooltip: 'Capture Controls',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Container(
            margin: const EdgeInsets.only(left: 8, right: 150),
            height: 3,
            color: Colors.lightGreenAccent,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _fetchFeedItems(showLoader: false),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: feedItems.length,
                    itemBuilder: (context, index) {
                      final item = feedItems[index];
                      final confidence =
                          ((item['confidence'] as double) * 100).toStringAsFixed(1);
                      final aiSummary = item['aiSummary'] as String?;
                      final imageUrl = item['image'] as String;
                      final downloadKey = item['capturedOn'] as String? ?? imageUrl;
                      final isDownloading = _downloadLoadingKeys.contains(downloadKey);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
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
                                onTap: () => _openFullView(imageUrl),
                                child: Image.network(
                                  imageUrl,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    height: 180,
                                    color: Colors.grey,
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
                            const SizedBox(height: 6),
                            Text(
                              'Captured on: ${_formatCapturedTime(item['capturedOn'] as String?)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Risk ${item['riskScore']} • ${item['priority']}',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (aiSummary != null && aiSummary.trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  aiSummary,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                onPressed: () => _openFullView(imageUrl),
                                tooltip: 'Full screen',
                                icon: const Icon(
                                  Icons.fullscreen,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isDownloading
                                    ? null
                                    : () => _downloadImage(downloadKey, imageUrl),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                ),
                                child: isDownloading
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Download'),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
