import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/crimechart.dart';

class SeasonsPage extends StatefulWidget {
  const SeasonsPage({super.key});

  @override
  _SeasonsPageState createState() => _SeasonsPageState();
}

class _SeasonsPageState extends State<SeasonsPage> {
  Future<Map<String, dynamic>>? _allData;

  @override
  void initState() {
    super.initState();
    _allData = fetchAllData();
  }

  Future<Map<String, dynamic>> fetchAllData() async {
    final responses = await Future.wait([
      http.get(Uri.parse('http://127.0.0.1:8000/api/seasons')),
      http.get(Uri.parse('http://127.0.0.1:8000/api/season_analysis')),
    ]);
    if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
      return {
        'exploratory': json.decode(responses[0].body),
        'mining': json.decode(responses[1].body),
      };
    } else {
      throw Exception('Failed to load one or both endpoints');
    }
  }

  Widget _buildExploratorySection(Map<String, dynamic> data) {
    final seasonCrime = data['season_crime'] as List;
    final seasonWeapon = data['season_weapon'] as List;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Exploratory Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        // Text('Crime Types by Season', style: TextStyle(fontWeight: FontWeight.bold)),
        buildCrimeBarChart(seasonCrime),
        buildCrimeBarChart(seasonWeapon)
        // ...seasonCrime.map((item) => ListTile(
        //   title: Text('${item['season']} - ${item['crime_type']}'),
        //   trailing: Text('${item['count']}'),
        // )),
        // Divider(),
        // Text('Weapon Usage by Season', style: TextStyle(fontWeight: FontWeight.bold)),
        // ...seasonWeapon.map((item) => ListTile(
        //   title: Text('${item['season']} - ${item['weapon_used']}'),
        //   trailing: Text('${item['count']}'),
        // )),
      ],
    );
  }

  Widget _buildMiningSection(Map<String, dynamic> data) {
    final aprioriRules = data['apriori_rules'] as List;
    final chiSquare = data['chi_square'] as Map<String, dynamic>;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Data Mining & Statistical Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text('Apriori Association Rules', style: TextStyle(fontWeight: FontWeight.bold)),
        buildAprioriTable(aprioriRules)
        // ...aprioriRules.map((rule) => ListTile(
        //   title: Text('If ${rule['antecedents']} → ${rule['consequents']}'),
        //   subtitle: Text('Support: ${rule['support'].toStringAsFixed(2)}, Confidence: ${rule['confidence'].toStringAsFixed(2)}, Lift: ${rule['lift'].toStringAsFixed(2)}'),
        // )),
        // Divider(),
        // Text('Chi-Square Test Results', style: TextStyle(fontWeight: FontWeight.bold)),
        // ListTile(
        //   title: Text('Season vs Crime Type'),
        //   subtitle: Text('Chi2: ${chiSquare['season_vs_crime_type']['chi2'].toStringAsFixed(2)}, p-value: ${chiSquare['season_vs_crime_type']['p_value'].toStringAsExponential(2)}'),
        // ),
        // ListTile(
        //   title: Text('Season vs Weapon Used'),
        //   subtitle: Text('Chi2: ${chiSquare['season_vs_weapon_used']['chi2']?.toStringAsFixed(2) ?? "N/A"}, p-value: ${chiSquare['season_vs_weapon_used']['p_value']?.toStringAsExponential(2) ?? "N/A"}'),
        // ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Seasonal Crime Patterns')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _allData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return Center(child: Text('No data'));
          }
          final exploratory = snapshot.data!['exploratory'];
          final mining = snapshot.data!['mining'];
          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              _buildExploratorySection(exploratory),
              SizedBox(height: 24),
              _buildMiningSection(mining),
            ],
          );
        },
      ),
    );
  }
}