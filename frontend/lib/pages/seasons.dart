import 'package:flutter/material.dart';
import 'package:crime_analysis/widgets/crimechart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SeasonsPage extends StatefulWidget {
  const SeasonsPage({super.key});

  @override
  State<SeasonsPage> createState() => _SeasonsPageState();
}

class _SeasonsPageState extends State<SeasonsPage> with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _exploratoryDataFuture;
  Map<String, dynamic>? _aprioriResult;
  bool _isAprioriLoading = false;
  String? _aprioriErrorMessage;

  late TabController _tabController; // Declare TabController

  @override
  void initState() {
    super.initState();
    _exploratoryDataFuture = _fetchExploratoryData();
    _tabController = TabController(length: 2, vsync: this); // Initialize TabController
  }

  @override
  void dispose() {
    _tabController.dispose(); // Dispose TabController
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchExploratoryData() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/api/seasons'));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to load exploratory data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to connect to server for exploratory data: $e');
    }
  }

  Future<void> _runAprioriAnalysis() async {
    setState(() {
      _isAprioriLoading = true;
      _aprioriErrorMessage = null;
      _aprioriResult = null; // Clear previous results when running again
    });

    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/api/weather_analysis'));
      if (response.statusCode == 200) {
        setState(() {
          _aprioriResult = json.decode(response.body) as Map<String, dynamic>;
        });
      } else {
        String errorDetail = 'Unknown error';
        try {
          final errorJson = json.decode(response.body);
          if (errorJson.containsKey('detail')) {
            errorDetail = errorJson['detail'];
          }
        } catch (_) {
          errorDetail = response.body;
        }
        setState(() {
          _aprioriErrorMessage = 'Failed to run Apriori analysis: ${response.statusCode} - $errorDetail';
        });
      }
    } catch (e) {
      setState(() {
        _aprioriErrorMessage = 'Error connecting to the server for Apriori: $e';
      });
    } finally {
      setState(() {
        _isAprioriLoading = false;
      });
    }
  }

  // Helper to map weapon_used numerical values to readable strings
  String _mapWeaponUsedValue(dynamic value) {
    if (value == 0) return 'No Weapon Used';
    if (value == 1) return 'Weapon Used';
    return value.toString();
  }

  // --- Widgets for Table View ---
  Widget _buildSeasonCategoryStatsTable(List data, String categoryKey, String tableTitle) {
    if (data.isEmpty) {
      return Text('No data available for $tableTitle.');
    }

    Map<String, Map<String, dynamic>> seasonSummary = {};
    for (var item in data) {
      final season = item['season'] as String;
      final category = categoryKey == 'weapon_used' ? _mapWeaponUsedValue(item[categoryKey]) : item[categoryKey] as String;
      final count = item['count'] as int;

      if (!seasonSummary.containsKey(season)) {
        seasonSummary[season] = {
          'total_count': 0,
          'most_frequent_category': '',
          'max_category_count': 0,
        };
      }
      seasonSummary[season]!['total_count'] += count;

      if (count > seasonSummary[season]!['max_category_count']) {
        seasonSummary[season]!['max_category_count'] = count;
        seasonSummary[season]!['most_frequent_category'] = category;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tableTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DataTable(
          columns: [
            DataColumn(label: Text('Season')),
            DataColumn(label: Text('Total Count')),
            DataColumn(label: Text('Most Frequent ${categoryKey.split('_').map((s) => s[0].toUpperCase() + s.substring(1)).join(' ')}')),
          ],
          rows: seasonSummary.entries.map((entry) {
            final season = entry.key;
            final summary = entry.value;
            return DataRow(cells: [
              DataCell(Text(season)),
              DataCell(Text(summary['total_count'].toString())),
              DataCell(Text('${summary['most_frequent_category']} (${summary['max_category_count']})')),
            ]);
          }).toList(),
        ),
      ],
    );
  }

  // Content for the "Tables" tab
  Widget _buildTablesContent(Map<String, dynamic> exploratoryData) {
    final seasonCrime = exploratoryData['season_crime'] as List;
    final seasonWeapon = exploratoryData['season_weapon'] as List;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(child: Text('Exploratory Analysis', style: Theme.of(context).textTheme.headlineSmall)),
        const SizedBox(height: 16),
        _buildSeasonCategoryStatsTable(seasonCrime, 'crime_type', 'Crime Stats by Season'),
        const SizedBox(height: 24),
        _buildSeasonCategoryStatsTable(seasonWeapon, 'weapon_used', 'Weapon Usage Stats by Season'),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              side: BorderSide(color: Theme.of(context).primaryColor, width: 2),
            ),
            onPressed: _isAprioriLoading ? null : _runAprioriAnalysis,
            child: _isAprioriLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Run Apriori Analysis'),
          ),
        ),
        if (_aprioriErrorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text(
              'Error: $_aprioriErrorMessage',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        const SizedBox(height: 24),
        if (_aprioriResult != null)
          _buildMiningTables(_aprioriResult!),
        if (!_isAprioriLoading && _aprioriResult == null && _aprioriErrorMessage == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Press button to see data mining results.'),
            ),
          )
      ],
    );
  }

  // Mining tables for the "Tables" tab
  Widget _buildMiningTables(Map<String, dynamic> miningData) {
    final aprioriRules = miningData['apriori_rules'] as List;
    final top5Rules = miningData['top 5 rules'] as List;
    final chiSquare = miningData['chi_square'] as Map<String, dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Text('Data Mining Analysis', style: Theme.of(context).textTheme.headlineSmall)),
        const SizedBox(height: 16),
        Text('Chi-Square Tests:', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('Season vs Crime Type: Chi2=${chiSquare['season_vs_crime_type']['chi2']?.toStringAsFixed(2)}, P-value=${chiSquare['season_vs_crime_type']['p_value']?.toStringAsFixed(3)}'),
        Text('Season vs Weapon Used: Chi2=${chiSquare['season_vs_weapon_used']['chi2']?.toStringAsFixed(2)}, P-value=${chiSquare['season_vs_weapon_used']['p_value']?.toStringAsFixed(3)}'),
        const SizedBox(height: 16),
        Center(child: Text('All Apriori Rules:', style: const TextStyle(fontWeight: FontWeight.bold,fontSize: 18))),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: buildAprioriTable(aprioriRules)),
        const SizedBox(height: 16),
        Center(child: Text('Top 5 Apriori Rules:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: buildAprioriTable(top5Rules)),
      ],
    );
  }

  // --- Widgets for Graphs View ---
  // Content for the "Graphs" tab
  Widget _buildGraphsContent(Map<String, dynamic> exploratoryData) {
    final seasonCrime = exploratoryData['season_crime'] as List;
    final seasonWeapon = exploratoryData['season_weapon'] as List;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(child:Text('Exploratory Analysis', style: Theme.of(context).textTheme.headlineSmall)),
        const SizedBox(height: 16),
        Center(child:Text('Crime Types by Season', style: const TextStyle(fontWeight: FontWeight.bold))),
        buildCrimeBarChart(context, seasonCrime, categoryKey: 'crime_type'), // Pass context
        const SizedBox(height: 16),
        Center(child:Text('Weapon Usage by Season', style: const TextStyle(fontWeight: FontWeight.bold))),
        buildCrimeBarChart(context, seasonWeapon, categoryKey: 'weapon_used'), // Pass context
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              side: BorderSide(color: Theme.of(context).primaryColor, width: 2),
            ),
            onPressed: _isAprioriLoading ? null : _runAprioriAnalysis,
            child: _isAprioriLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Run Apriori Analysis'),
          ),
        ),
        if (_aprioriErrorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text(
              'Error: $_aprioriErrorMessage',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        const SizedBox(height: 24),
        if (_aprioriResult != null)
          _buildMiningGraphs(_aprioriResult!),
        if (!_isAprioriLoading && _aprioriResult == null && _aprioriErrorMessage == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Push button to see data mining results.'),
            ),
          )
      ],
    );
  }

  // Mining graphs for the "Graphs" tab (currently placeholders)
  Widget _buildMiningGraphs(Map<String, dynamic> miningData) {
    final globalRelationships = miningData['charts']['global_relationships'] as Map<String, dynamic>;
    final top5RulesChart = miningData['charts']['top_5_rules_chart'] as List;
    final List<Map<String, dynamic>> seasonVsCrimeData = 
        (globalRelationships['season_vs_crime_type'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
    final List<Map<String, dynamic>> seasonVsWeaponData = 
        (globalRelationships['season_vs_weapon_used'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child:Text('Data Mining Analysis', style: Theme.of(context).textTheme.headlineSmall)),
        const SizedBox(height: 16),
        Center(child:Text('Season and Crime Type Heatmap', style: const TextStyle(fontWeight: FontWeight.bold,fontSize: 16))),
        const SizedBox(height: 8),
        buildGenericHeatmap(
          data: seasonVsCrimeData,
          primaryKey: 'season',
          valueMapKey: 'crime_counts',
          title: 'Crime Types by Season',
          maxColorValue: 1000, // <<-- ADJUST THIS VALUE based on maximum crime counts in your data
        ),
        const SizedBox(height: 16),
        Center(child:Text('Season and Weapon Used Heatmap', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        const SizedBox(height: 16),
        buildGenericHeatmap(
          data: seasonVsWeaponData,
          primaryKey: 'season',
          valueMapKey: 'weapon_counts',
          title: 'Weapon Usage by Season',
          maxColorValue: 500, // <<--ADJUST THIS VALUE based on maximum weapon usage counts in your data
        ),
        const SizedBox(height: 16),
        Center(child:Text('Top 5 Apriori Rules (Lift)', style: const TextStyle(fontWeight: FontWeight.bold,fontSize: 16))),
        const SizedBox(height: 16),
        buildAprioriRulesBarChart(top5RulesChart, metric: 'lift'),
        const SizedBox(height: 16),
        Center(child:Text('Top 5 Apriori Rules (Confidence)', style: const TextStyle(fontWeight: FontWeight.bold,fontSize: 16))),
        const SizedBox(height: 16),
        buildAprioriRulesBarChart(top5RulesChart, metric: 'confidence'),
      ],
    );
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seasonal Crime Patterns'),
        bottom: TabBar( // Added TabBar to the AppBar
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tables'),
            Tab(text: 'Graphs'),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _exploratoryDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No data'));
          }
          final exploratory = snapshot.data!;
          return TabBarView( // Added TabBarView to the body
            controller: _tabController,
            children: [
              // Tab 1: Tables View
              _buildTablesContent(exploratory),
              // Tab 2: Graphs View
              _buildGraphsContent(exploratory),
           ],
          );
        },
      ),
    );
  }
}