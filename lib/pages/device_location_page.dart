import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/app_api.dart';

class DeviceLocationPage extends StatefulWidget {
  const DeviceLocationPage({super.key});

  @override
  State<DeviceLocationPage> createState() => _DeviceLocationPageState();
}

class _DeviceLocationPageState extends State<DeviceLocationPage> {
  static const String _mapTilerKey = String.fromEnvironment(
    'MAPTILER_KEY',
    defaultValue: '',
  );
  final LatLng _center = LatLng(10.2797, 122.8563);
  List<Map<String, dynamic>> _devices = [];
  bool _loading = true;
  String? _error;
  LatLng? _selectedLocation;
  String? _selectedDeviceLabel;
  late final MapController _mapController; // ✅ Added controller

  @override
  void initState() {
    super.initState();
    _mapController = MapController(); // ✅ Initialize controller
    _fetchDevices();
  }

  Future<void> _fetchDevices() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await AppApi.getAdmin(
        '/devices',
        queryParameters: AppApi.reportQuery({
          'offlineAfterSeconds': '180',
        }),
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = response.statusCode == 401
              ? 'Admin session expired. Log in again.'
              : 'Failed to load devices: ${response.statusCode}';
        });
        return;
      }

      final List<dynamic> data = response.body.isNotEmpty
          ? (jsonDecode(response.body) as List<dynamic>)
          : [];
      final devices = data.map<Map<String, dynamic>>((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final lat = map['lat'];
        final lng = map['lng'];
        final hasLocation =
            lat is num && lng is num && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
        return {
          'deviceId': map['deviceId']?.toString() ?? 'unknown',
          'name': map['name']?.toString() ?? 'unknown',
          'status': map['status']?.toString() ?? 'offline',
          'online': map['online'] == true,
          'lastSeen': map['lastSeen']?.toString(),
          'lat': hasLocation ? lat.toDouble() : null,
          'lng': hasLocation ? lng.toDouble() : null,
        };
      }).toList();

      LatLng? initialLocation;
      String? initialLabel;
      if (_selectedLocation == null) {
        for (final device in devices) {
          final lat = device['lat'] as double?;
          final lng = device['lng'] as double?;
          if (lat != null && lng != null) {
            initialLocation = LatLng(lat, lng);
            initialLabel = device['name']?.toString() ?? device['deviceId'];
            break;
          }
        }
      }

      setState(() {
        _devices = devices;
        _loading = false;
        if (_selectedLocation == null && initialLocation != null) {
          _selectedLocation = initialLocation;
          _selectedDeviceLabel = initialLabel;
        }
      });

      if (initialLocation != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(initialLocation!, 15.5);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load devices: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMapKey = _mapTilerKey.trim().isNotEmpty;
    final markerPoint = _selectedLocation;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                'Devices Location Map',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_selectedDeviceLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Pinned: $_selectedDeviceLabel',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
            if (_selectedDeviceLabel == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Tap a device to pin its location.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ),
            SizedBox(
              height: 300,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: 14.0,
                    ),
                    children: [
                      if (hasMapKey)
                        TileLayer(
                          urlTemplate:
                              'https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=$_mapTilerKey',
                          userAgentPackageName: 'wildpulse_prototype_app',
                        )
                      else
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'wildpulse_prototype_app',
                        ),
                      MarkerLayer(
                        markers: [
                          if (markerPoint != null)
                            Marker(
                              point: markerPoint,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
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
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        )
                      : _devices.isEmpty
                          ? const Center(
                              child: Text(
                                'No devices registered yet.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _devices.length,
                              itemBuilder: (context, index) {
                                final device = _devices[index];
                                final isOnline = device['online'] == true;
                                final status =
                                    device['status']?.toString() ?? 'offline';
                                final deviceId =
                                    device['deviceId']?.toString() ?? '';
                                final deviceName =
                                    device['name']?.toString() ?? deviceId;
                                final lat = device['lat'] as double?;
                                final lng = device['lng'] as double?;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 4,
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () {
                                      LatLng? target;
                                      if (lat != null && lng != null) {
                                        target = LatLng(lat, lng);
                                      }
                                      if (target == null) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'No pinned location available for this device.',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      setState(() {
                                        _selectedLocation = target;
                                        _selectedDeviceLabel = deviceName;
                                      });
                                      _mapController.move(target, 15.5);
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1F1F1F),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                deviceName,
                                                style: const TextStyle(
                                                    color: Colors.white),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Status: $status',
                                                style: TextStyle(
                                                  color: isOnline
                                                      ? Colors.greenAccent
                                                      : Colors.orangeAccent,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Icon(
                                            Icons.location_pin,
                                            color: isOnline
                                                ? Colors.green
                                                : Colors.grey,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
