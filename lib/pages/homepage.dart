import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'notification.dart';
import 'monitoring.dart';
import 'reports.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.22.85:3000/api',
  );

  int _currentNavIndex = 0;
  int _currentFeaturedIndex = 0;
  final PageController _pageController = PageController();
  final TextEditingController _conservationSearchController =
      TextEditingController();
  Timer? _conservationSearchDebounce;
  Map<String, dynamic>? _dashboardData;
  bool _dashboardLoading = true;
  String? _dashboardError;
  List<Map<String, dynamic>> _conservationList = [];
  bool _conservationLoading = true;
  String? _conservationError;

  final List<Map<String, String>> featuredAnimals = [
    {
      'image': 'assets/visayan_spotted_deer.jpg',
      'label': 'Visayan Spotted Deer',
    },
    {'image': 'assets/philippine_hornbill.jpg', 'label': 'Philippine Hornbill'},
    {'image': 'assets/visayan_warty_pig.jpg', 'label': 'Visayan Warty Pig'},
  ];

  void _onNavBarTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchDashboardOverview();
    _fetchConservationList();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _conservationSearchDebounce?.cancel();
    _conservationSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboardOverview() async {
    setState(() {
      _dashboardLoading = true;
      _dashboardError = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/dashboard/overview?days=7'),
      );
      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          _dashboardLoading = false;
          _dashboardError = 'Dashboard load failed: ${response.statusCode}';
        });
        return;
      }

      setState(() {
        _dashboardData = jsonDecode(response.body) as Map<String, dynamic>;
        _dashboardLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dashboardLoading = false;
        _dashboardError = 'Dashboard load failed: $e';
      });
    }
  }

  void _onConservationSearchChanged(String value) {
    _conservationSearchDebounce?.cancel();
    _conservationSearchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _fetchConservationList(query: value),
    );
  }

  Future<void> _fetchConservationList({String? query}) async {
    setState(() {
      _conservationLoading = true;
      _conservationError = null;
    });

    try {
      final q = (query ?? _conservationSearchController.text).trim();
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/conservation/list?limit=50&q=${Uri.encodeQueryComponent(q)}',
        ),
      );
      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          _conservationLoading = false;
          _conservationError =
              'Conservation list load failed: ${response.statusCode}';
        });
        return;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (body['results'] as List<dynamic>? ?? [])
          .map(
            (item) => Map<String, dynamic>.from(item as Map<String, dynamic>),
          )
          .toList();

      setState(() {
        _conservationList = items;
        _conservationLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _conservationLoading = false;
        _conservationError = 'Conservation list load failed: $e';
      });
    }
  }

  Widget _metricTile(String label, dynamic value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 4),
            Text(
              '${value ?? 0}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTrendChart(List<dynamic> trend) {
    final counts = trend.map((e) => (e['count'] as num?)?.toDouble() ?? 0).toList();
    final maxCount = counts.isEmpty ? 1.0 : counts.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '7-Day Capture Trend',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: trend.map((item) {
                final count = (item['count'] as num?)?.toDouble() ?? 0;
                final day = (item['day']?.toString() ?? '--').split('-').last;
                final barHeight = maxCount == 0 ? 2.0 : (count / maxCount) * 60;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: barHeight < 2 ? 2 : barHeight,
                          decoration: BoxDecoration(
                            color: Colors.lightGreenAccent,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          day,
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSpeciesChart(List<dynamic> species) {
    final maxCount = species.isEmpty
        ? 1.0
        : species
            .map((e) => (e['count'] as num?)?.toDouble() ?? 0)
            .reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Species',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...species.map((item) {
            final name = item['species']?.toString() ?? 'unknown';
            final count = (item['count'] as num?)?.toDouble() ?? 0;
            final widthFactor = maxCount == 0 ? 0.0 : count / maxCount;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$name (${count.toInt()})',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  LinearProgressIndicator(
                    value: widthFactor,
                    minHeight: 6,
                    color: Colors.amberAccent,
                    backgroundColor: Colors.white12,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHomePageContent() {
    return ListView(
      padding: const EdgeInsets.all(12.0),
      children: [
          SizedBox(
            height: 180,
            child: PageView.builder(
              itemCount: featuredAnimals.length,
              onPageChanged: (index) {
                setState(() {
                  _currentFeaturedIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        featuredAnimals[index]['image']!,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          featuredAnimals[index]['label']!.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(featuredAnimals.length, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      _currentFeaturedIndex == index
                          ? Colors.greenAccent[400]
                          : Colors.grey,
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Live Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              TextButton(
                onPressed: _fetchDashboardOverview,
                child: const Text(
                  'Refresh',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          if (_dashboardLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(),
            ),
          if (_dashboardError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _dashboardError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          if (_dashboardData != null) ...[
            Builder(
              builder: (context) {
                final totals =
                    (_dashboardData!['totals'] as Map<String, dynamic>? ?? {});
                final dailyTrend =
                    (_dashboardData!['dailyTrend'] as List<dynamic>? ?? []);
                final topSpecies =
                    (_dashboardData!['topSpecies'] as List<dynamic>? ?? []);

                return Column(
                  children: [
                    Row(
                      children: [
                        _metricTile(
                          'Captures (7d)',
                          totals['captures'],
                          Colors.lightGreenAccent,
                        ),
                        const SizedBox(width: 8),
                        _metricTile(
                          'Needs Review',
                          totals['needs_review'],
                          Colors.amberAccent,
                        ),
                        const SizedBox(width: 8),
                        _metricTile(
                          'Alerts',
                          totals['alerts'],
                          Colors.redAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildDailyTrendChart(dailyTrend),
                    const SizedBox(height: 10),
                    _buildTopSpeciesChart(topSpecies),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Animal Conservation List',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              TextButton(
                onPressed: () => _fetchConservationList(),
                child: const Text(
                  'Refresh',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _conservationSearchController,
            onChanged: _onConservationSearchChanged,
            onSubmitted: (value) => _fetchConservationList(query: value),
            decoration: InputDecoration(
              hintText: 'Search conservation list (name, status, category)',
              fillColor: Colors.grey[850],
              filled: true,
              prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, color: Colors.white54),
                onPressed: () {
                  _conservationSearchController.clear();
                  _fetchConservationList(query: '');
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          if (_conservationLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(),
            ),
          if (_conservationError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _conservationError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          if (!_conservationLoading &&
              _conservationError == null &&
              _conservationList.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'No conservation entries found.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ..._conservationList.map((animal) {
            final commonName = animal['commonName']?.toString() ?? 'Unknown Animal';
            final scientificName =
                animal['scientificName']?.toString() ?? 'Unknown species';
            final category = animal['category']?.toString() ?? 'Unknown';
            final status =
                animal['conservationStatus']?.toString() ?? 'Unknown status';
            final image = animal['image']?.toString() ?? '';

            return Card(
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: image.startsWith('http')
                      ? Image.network(
                          image,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 70,
                            height: 70,
                            color: Colors.black26,
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.white54,
                            ),
                          ),
                        )
                      : Image.asset(
                          image,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
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
                title: Text(
                  '$commonName ($scientificName)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '$category • $status',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ),
            );
          }),
        ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.black,
          title: Row(
            children: const [
              Icon(Icons.pets, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'Wild Pulse Dashboard',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          elevation: 0,
        ),
        backgroundColor: Colors.black87,
        body: _buildHomePageContent(),
      ),
      const ReportsPage(),
      const NotificationPage(),
      const MonitoringFeedPage(),
    ];

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _currentNavIndex = index;
          });
        },
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: const Color.fromARGB(255, 243, 219, 7),
        unselectedItemColor: Colors.grey,
        currentIndex: _currentNavIndex,
        onTap: _onNavBarTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: ''),
          BottomNavigationBarItem(
            icon: Icon(Icons.fact_check_outlined),
            label: '',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.photo_library_outlined), label: ''),
        ],
      ),
    );
  }
}
