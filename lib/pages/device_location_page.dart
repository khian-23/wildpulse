import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DeviceLocationPage extends StatefulWidget {
  const DeviceLocationPage({super.key});

  @override
  State<DeviceLocationPage> createState() => _DeviceLocationPageState();
}

class _DeviceLocationPageState extends State<DeviceLocationPage> {
  final LatLng _center = LatLng(10.2797, 122.8563);
  final List<String> _cameras = ['Camera 1', 'Camera 2', 'Camera 3'];
  late final MapController _mapController; // ✅ Added controller

  @override
  void initState() {
    super.initState();
    _mapController = MapController(); // ✅ Initialize controller
  }

  @override
  Widget build(BuildContext context) {
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
                      TileLayer(
                        urlTemplate:
                            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _center,
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
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _cameras.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 4,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F1F1F),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _cameras[index],
                            style: const TextStyle(color: Colors.white),
                          ),
                          const Icon(Icons.location_pin, color: Colors.green),
                        ],
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
