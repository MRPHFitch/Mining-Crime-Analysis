import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../widgets/crimechart.dart';

class ChartsPage extends StatefulWidget {
  const ChartsPage({super.key});

  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {
  // sample fallback data
  List<Map<String, dynamic>> _hotspotGrid = const [
    {
      "lat_band": "34.00 - 34.05",
      "values": {"-118.30": 12, "-118.25": 21, "-118.20": 33, "-118.15": 18}
    },
    {
      "lat_band": "34.06 - 34.10",
      "values": {"-118.30": 8, "-118.25": 14, "-118.20": 27, "-118.15": 11}
    },
  ];
  List<_Hotspot> _hotspots = const [
    _Hotspot(lat: 34.0522, lon: -118.2437, count: 42),
    _Hotspot(lat: 34.0407, lon: -118.2690, count: 25),
    _Hotspot(lat: 34.0739, lon: -118.2390, count: 31),
  ];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    const baseUrl = 'http://127.0.0.1:8000';
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final hotspotsResp = await http.post(
        Uri.parse('$baseUrl/api/hotspots'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'k': 15,
          'datetime_col': 'date',
          'time_col': 'time',
          'lat_col': 'latitude',
          'lon_col': 'longitude',
        }),
      );

      if (hotspotsResp.statusCode == 200) {
        final data = json.decode(hotspotsResp.body) as Map<String, dynamic>;
        final centroids = data['centroids'] as List<dynamic>;
        final counts = (data['counts'] as Map).map<String, int>(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()),
        );

        _hotspots = centroids.map<_Hotspot>((c) {
          final clusterId = c['cluster'].toString();
          final count = counts[clusterId] ?? 0;
          return _Hotspot(
            lat: (c['latitude'] as num).toDouble(),
            lon: (c['longitude'] as num).toDouble(),
            count: count,
          );
        }).toList();
      } else {
        _error = 'Hotspots request failed (${hotspotsResp.statusCode})';
      }

      final gridResp = await http.get(Uri.parse('$baseUrl/api/hotspot_grid'));
      if (gridResp.statusCode == 200) {
        final gridJson = json.decode(gridResp.body) as Map<String, dynamic>;
        final grid = (gridJson['grid'] as List<dynamic>).cast<Map<String, dynamic>>();
        if (grid.isNotEmpty) {
          _hotspotGrid = grid;
        }
      } else {
        _error = 'Heatmap request failed (${gridResp.statusCode})';
      }
    } catch (e) {
      _error = 'Error loading data: $e';
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // Sample time-of-day buckets (could be swapped with API results)
  Map<String, int> get _hourBuckets => const {
        "0-3": 18,
        "3-6": 12,
        "6-9": 25,
        "9-12": 38,
        "12-15": 42,
        "15-18": 51,
        "18-21": 47,
        "21-24": 33,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Charts and Heatmaps')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                Text(
                  'Hotspot Map',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 2,
                  child: SizedBox(
                    height: 320,
                    child: _buildHotspotMap(_hotspots),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Hotspot Heatmap',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: buildGenericHeatmap(
                      data: _hotspotGrid,
                      primaryKey: "lat_band",
                      valueMapKey: "values",
                      title: "Crime density by lat/long bucket",
                      baseColor: Colors.red,
                      maxColorValue: 60,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Time-of-Day Histogram',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: _buildTimeOfDayHistogram(context, _hourBuckets),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Live data from /api/hotspots and /api/hotspot_grid (falls back to sample data on error).',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}

Widget _buildHotspotMap(List<_Hotspot> hotspots) {
  if (hotspots.isEmpty) {
    return const Center(child: Text('No hotspot data'));
  }

  final maxCount = hotspots.fold<int>(1, (prev, h) => h.count > prev ? h.count : prev);

  return FlutterMap(
    options: MapOptions(
      initialCenter: LatLng(hotspots.first.lat, hotspots.first.lon),
      initialZoom: 12.0,
      interactionOptions: const InteractionOptions(
        flags: InteractiveFlag.all,
      ),
    ),
    children: [
      TileLayer(
        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
        subdomains: const ['a', 'b', 'c'],
        userAgentPackageName: 'com.example.crime_analysis',
      ),
      CircleLayer(
        circles: hotspots.map((entry) {
          final intensity = entry.count / maxCount;
          return CircleMarker(
            point: LatLng(entry.lat, entry.lon),
            color: Colors.red.withValues(alpha:(.2 + 0.6 * intensity)),
            borderStrokeWidth: 2,
            borderColor: Colors.redAccent,
            radius: 50 + 80 * intensity, // meters
          );
        }).toList(),
      ),
      MarkerLayer(
        markers: hotspots.map<Marker>((entry) {
          return Marker(
            width: 80,
            height: 40,
            point: LatLng(entry.lat, entry.lon),
            child: Card(
              color: Colors.black.withValues(alpha: .7),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  '${entry.count} incidents',
                  style: const TextStyle(color: Colors.white, fontSize: 8),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ],
  );
}

class _Hotspot {
  final double lat;
  final double lon;
  final int count;

  const _Hotspot({
    required this.lat,
    required this.lon,
    required this.count,
  });
}

Widget _buildTimeOfDayHistogram(BuildContext context, Map<String, int> buckets) {
  final entries = buckets.entries.toList();
  final maxY = (buckets.values.reduce((a, b) => a > b ? a : b) * 1.2).ceilToDouble();
  final barColor = Theme.of(context).colorScheme.primary;

  return SizedBox(
    height: 280,
    child: BarChart(
      BarChartData(
        maxY: maxY,
        barGroups: List.generate(entries.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: entries[i].value.toDouble(),
                color: barColor,
                width: 18,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    entries[idx].key,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => Text(value.toInt().toString()),
            ),
          ),
        ),
        gridData: FlGridData(show: true, horizontalInterval: (maxY / 5).clamp(1, maxY)),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => Colors.black87,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${entries[group.x.toInt()].key}\n${rod.toY.toInt()} incidents',
                const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
      ),
    ),
  );
}
