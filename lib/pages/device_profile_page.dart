import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/app_api.dart';

class DeviceProfilePage extends StatefulWidget {
  final String deviceId;

  const DeviceProfilePage({super.key, required this.deviceId});

  @override
  State<DeviceProfilePage> createState() => _DeviceProfilePageState();
}

class _DeviceProfilePageState extends State<DeviceProfilePage> {
  static const String _mapTilerKey = String.fromEnvironment(
    'MAPTILER_KEY',
    defaultValue: '',
  );
  String _resolvedMapKey() {
    final dartDefine = _mapTilerKey.trim();
    if (dartDefine.isNotEmpty && dartDefine != 'YOUR_MAPTILER_KEY') {
      return dartDefine;
    }
    final envKey = (dotenv.env['MAPTILER_KEY'] ?? '').trim();
    if (envKey.isNotEmpty && envKey != 'YOUR_MAPTILER_KEY') {
      return envKey;
    }
    return '';
  }

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _device;
  List<Map<String, dynamic>> _captures = [];
  bool _capturesUnscoped = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _loading = true;
      _error = null;
      _capturesUnscoped = false;
    });

    try {
      final devicesResponse = await AppApi.getAdmin(
        '/devices',
        queryParameters: AppApi.reportQuery({'offlineAfterSeconds': '180'}),
      );
      if (!mounted) return;

      if (devicesResponse.statusCode != 200) {
        setState(() {
          _loading = false;
          _error =
              devicesResponse.statusCode == 401
                  ? 'Admin session expired. Log in again.'
                  : 'Failed to load device profile: ${devicesResponse.statusCode}';
        });
        return;
      }

      final List<dynamic> deviceList =
          devicesResponse.body.isNotEmpty
              ? (jsonDecode(devicesResponse.body) as List<dynamic>)
              : [];
      final device = deviceList
          .map((item) => Map<String, dynamic>.from(item as Map))
          .firstWhere(
            (item) => item['deviceId']?.toString() == widget.deviceId,
            orElse: () => <String, dynamic>{},
          );

      if (device.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Device ${widget.deviceId} not found.';
        });
        return;
      }

      final imagesResponse = await AppApi.getAdmin(
        '/images',
        queryParameters: AppApi.reportQuery({
          'limit': '50',
          'deviceId': widget.deviceId,
        }),
      );
      if (!mounted) return;

      List<Map<String, dynamic>> captures = [];
      if (imagesResponse.statusCode == 200 &&
          imagesResponse.body.isNotEmpty) {
        final List<dynamic> items = jsonDecode(imagesResponse.body);
        captures =
            items.map<Map<String, dynamic>>((item) {
              return Map<String, dynamic>.from(item as Map);
            }).toList();

        final filtered =
            captures.where((item) {
              final itemDeviceId =
                  item['deviceId'] ??
                  item['device_id'] ??
                  item['device'];
              return itemDeviceId?.toString() == widget.deviceId;
            }).toList();

        if (filtered.isNotEmpty) {
          captures = filtered;
        } else {
          _capturesUnscoped = true;
          captures = captures.take(10).toList();
        }
      }

      setState(() {
        _device = device;
        _captures = captures;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load device profile: $e';
      });
    }
  }

  String _formatDateTime(String? isoTime) {
    if (isoTime == null || isoTime.isEmpty) return 'Unknown';
    try {
      final dateTime = DateTime.parse(isoTime).toLocal();
      final month = _monthName(dateTime.month);
      final day = dateTime.day.toString().padLeft(2, '0');
      final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '$month $day, ${dateTime.year} • $hour:$minute $period';
    } catch (_) {
      return 'Unknown';
    }
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

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(double? lat, double? lng) {
    final hasLocation =
        lat != null &&
        lng != null &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
    final resolvedKey = _resolvedMapKey();
    final hasMapKey = resolvedKey.trim().isNotEmpty;

    if (!hasLocation) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'No pinned location available for this device.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final point = LatLng(lat!, lng!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 14,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                if (hasMapKey)
                  TileLayer(
                    urlTemplate:
                        'https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=$resolvedKey',
                    userAgentPackageName: 'wildpulse_prototype_app',
                  )
                else
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'wildpulse_prototype_app',
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.redAccent,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!hasMapKey)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Map tiles are blocked. Set MAPTILER_KEY to enable maps.',
              style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Device Profile • ${widget.deviceId}'),
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
                onRefresh: _fetchProfile,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _device?['name']?.toString() ?? widget.deviceId,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _infoRow(
                            'Status',
                            _device?['status']?.toString() ?? 'unknown',
                            valueColor:
                                _device?['online'] == true
                                    ? Colors.greenAccent
                                    : Colors.orangeAccent,
                          ),
                          _infoRow(
                            'Last Seen',
                            _formatDateTime(_device?['lastSeen']?.toString()),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Location',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildLocationCard(
                      (_device?['lat'] as num?)?.toDouble(),
                      (_device?['lng'] as num?)?.toDouble(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          'Recent Captures',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (_capturesUnscoped)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Backend does not tag captures by device yet. Showing recent captures.',
                          style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (_captures.isEmpty)
                      const Text(
                        'No captures found.',
                        style: TextStyle(color: Colors.white70),
                      )
                    else
                      ..._captures.map((item) {
                        final species = item['species']?.toString() ?? 'unknown';
                        final capturedAt =
                            item['capturedAt']?.toString() ??
                            item['captured_at']?.toString() ??
                            item['createdAt']?.toString();
                        final confidence =
                            (item['confidence'] as num?)?.toDouble();
                        final imageUrl =
                            item['url']?.toString() ??
                            item['image_url']?.toString() ??
                            '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
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
                                      _formatDateTime(capturedAt),
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
