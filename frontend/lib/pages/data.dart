// File: /Users/Phoo/Classes/Data Mining/Project/Mining-Crime-Analysis/frontend/lib/pages/data_used.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DataPage extends StatefulWidget {
  const DataPage({super.key});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  late Future<List<Map<String, dynamic>>> _dataPreviewFuture;

  @override
  void initState() {
    super.initState();
    _dataPreviewFuture = _fetchDataPreview();
  }

  Future<List<Map<String, dynamic>>> _fetchDataPreview() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/api/cleaned_data_preview'));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load data preview: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error connecting to the server: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cleaned Data Preview')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _dataPreviewFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No data found.'));
          }

          final data = snapshot.data!;
          final columns = data.first.keys.toList();

          return SingleChildScrollView(
            scrollDirection: Axis.vertical, // Enable vertical scrolling for the whole table content
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal, // Enable horizontal scrolling for wide tables
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
          );
        },
      ),
    );
  }
}