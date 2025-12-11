import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DataPage extends StatefulWidget {
  const DataPage({super.key});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  // Use a map to store the results from both futures
  late Future<Map<String, List<Map<String, dynamic>>>> _allDataPreviewsFuture;

  @override
  void initState() {
    super.initState();
    _allDataPreviewsFuture = _fetchAllDataPreviews();
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchAllDataPreviews() async {
    final baseUrl = 'http://127.0.0.1:8000'; // Define base URL once

    try {
      // Fetch data from the main crime data endpoint
      final crimeDataResponse = await http.get(Uri.parse('$baseUrl/api/crime_data_preview'));
      if (crimeDataResponse.statusCode != 200) {
        throw Exception('Failed to load main crime data preview: ${crimeDataResponse.statusCode} - ${crimeDataResponse.body}');
      }
      final List<dynamic> crimeDataJsonList = json.decode(crimeDataResponse.body);
      final List<Map<String, dynamic>> crimeData = crimeDataJsonList.cast<Map<String, dynamic>>();

      // Fetch data from the cleaned safety data endpoint
      final safetyDataResponse = await http.get(Uri.parse('$baseUrl/api/cleaned_data_preview'));
      if (safetyDataResponse.statusCode != 200) {
        throw Exception('Failed to load crime safety data preview: ${safetyDataResponse.statusCode} - ${safetyDataResponse.body}');
      }
      final List<dynamic> safetyDataJsonList = json.decode(safetyDataResponse.body);
      final List<Map<String, dynamic>> safetyData = safetyDataJsonList.cast<Map<String, dynamic>>();

      return {
        'crime_data': crimeData,
        'safety_data': safetyData,
      };
    } catch (e) {
      throw Exception('Error connecting to the server: $e');
    }
  }

  // Helper widget to build a single data table
  Widget _buildDataTable(String title, List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('No data found for this source.'),
          ],
        ),
      );
    }

    final columns = data.first.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(child:Text(title, style: Theme.of(context).textTheme.headlineSmall)),
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: columns.map((col) => DataColumn(label: Text(col))).toList(),
              rows: data.map((row) {
                return DataRow(
                  cells: columns.map((col) {
                    return DataCell(Text(row[col]?.toString() ?? ''));
                  }).toList(),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 24), // Spacing between tables
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Used for Analysis')),
      body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: _allDataPreviewsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || (snapshot.data!['crime_data']!.isEmpty && snapshot.data!['safety_data']!.isEmpty)) {
            return const Center(child: Text('No data found from either source.'));
          }

          final crimeData = snapshot.data!['crime_data']!;
          final safetyData = snapshot.data!['safety_data']!;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  _buildDataTable('Crime Data Preview', crimeData),
                  _buildDataTable('Crime Safety Data Preview', safetyData),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}