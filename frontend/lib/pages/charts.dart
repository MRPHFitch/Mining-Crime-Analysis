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
  //Declare Variables
  List<Map<String, dynamic>> _hotspotGrid = const [];
  List<_Hotspot> _hotspots = const [];
  bool _loading = false;
  Map<String, int> _hourBuckets={};
  String? _error;
  final baseUrl = 'http://127.0.0.1:8000';

  @override
  void initState() {
    super.initState();
  }

  //Load up the data in such a way that you generate its creation not instant appearance
  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
      _hotspotGrid=[];
      _hotspots=[];
      _hourBuckets={};
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

      //Retrieve the hot spot values
      if(!mounted) return;
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
      //Retrieve the hot spot grid
      final gridResp = await http.get(Uri.parse('$baseUrl/api/hotspot_grid'));
      if(!mounted) return;
      if (gridResp.statusCode == 200) {
        final gridJson = json.decode(gridResp.body) as Map<String, dynamic>;
        final grid = (gridJson['grid'] as List<dynamic>).cast<Map<String, dynamic>>();
        if (grid.isNotEmpty) {
          _hotspotGrid = grid;
        }
      } else {
        _error = 'Heatmap request failed (${gridResp.statusCode})';
      }
      final hourBucketsResp=await http.get(Uri.parse('$baseUrl/api/time_of_day'));
      if(!mounted) return;
      if(hourBucketsResp.statusCode==200){
        final hourBucketsJson=json.decode(hourBucketsResp.body) as Map<String, dynamic>;
        _hourBuckets=hourBucketsJson.map<String, int>((key, value) => MapEntry(key.toString(), (value as num).toInt()),);
      }
      else{
        _error='Time-of-Day Hist request failed. (${hourBucketsResp.statusCode})';
      }
    } catch (e) {
      _error = 'Error loading data: $e';
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }
  
  List<Widget> _buildAllCharts(BuildContext context, ThemeData theme) {
    return [
      Center(
        child: Text(
          'Hotspot Map',
          style: theme.textTheme.titleLarge,
        ),
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
      Center(
        child: Text(
          'Hotspot Heatmap',
          style: theme.textTheme.titleLarge,
        ),
      ),
      const SizedBox(height: 8),
      Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: _hotspotGrid.isNotEmpty // Conditionally render heatmap
              ? buildGenericHeatmap(
                  data: _hotspotGrid,
                  primaryKey: "lat_band",
                  valueMapKey: "values",
                  title: "Crime density by lat/long bucket",
                  baseColor: Colors.red,
                  maxColorValue: 60,
                )
              : const Center(child: Text('No hotspot heatmap data')),
        ),
      ),
      const SizedBox(height: 24),
      Center(
        child: Text(
          'Time-of-Day Histogram',
          style: theme.textTheme.titleLarge,
        ),
      ),
      const SizedBox(height: 8),
      Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: _hourBuckets.isNotEmpty // Conditionally render histogram
              ? _buildTimeOfDayHistogram(context, _hourBuckets)
              : const Center(child: Text('No time-of-day histogram data')),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Charts and Heatmaps')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            // Place Button
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                side: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
              ),
              onPressed: _loading ? null : _loadData,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Generate'),
            ),
          ),
          const SizedBox(height: 16), // Spacing below button

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          // If no data is loaded yet (initial state or after clearing data due to error)
          else if (_hotspots.isEmpty && _hotspotGrid.isEmpty && _hourBuckets.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Press Button to Generate Maps and Charts'),
              ),
            )
          // If data is loaded and not currently loading, display charts
          else
            ..._buildAllCharts(context, theme),
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
              interval: (maxY/4).ceilToDouble(),
              getTitlesWidget: (value, meta) => Text(value.toInt().toString()),
            ),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: (maxY/4).ceilToDouble(),
              getTitlesWidget: (value, meta)=>Text(value.toInt().toString())
            )
          )
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
