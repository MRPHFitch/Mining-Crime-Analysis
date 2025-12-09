import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SequencesPage extends StatefulWidget {
  const SequencesPage({super.key});

  @override
  State<SequencesPage> createState() => _SequencesPageState();
}

class _SequencesPageState extends State<SequencesPage> {
  late Future<Map<String, dynamic>> _futureSequences;

  @override
  void initState() {
    super.initState();
    _futureSequences = _fetchSequences();
  }

  Future<Map<String, dynamic>> _fetchSequences() async {
    // Ensure the URL uses 127.0.0.1 for desktop app connectivity
    final url = Uri.parse("http://127.0.0.1:8000/api/crime_sequences");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      // Provide more detail in the exception message
      throw Exception("Failed to fetch crime sequences: ${response.statusCode} - ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recurring Crime Sequences")),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _futureSequences,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          // Handle cases where data might be null or 'patterns' key is missing
          if (!snapshot.hasData || snapshot.data == null || !snapshot.data!.containsKey('patterns')) {
            return const Center(child: Text("No frequent sequences found or data format is incorrect."));
          }

          final patterns = snapshot.data!["patterns"] as List;

          if (patterns.isEmpty) {
            return const Center(child: Text("No frequent sequences found."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: patterns.length,
            itemBuilder: (context, index) {
              final pattern = patterns[index];
              final crimes = (pattern["pattern"] as List).join(" → ");
              final support = pattern["support_pct"];

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4), // Added some vertical margin for better spacing
                child: ListTile(
                  title: Text(crimes),
                  subtitle: Text("Support: $support%"),
                ),
              );
            },
          );
        },
      ),
    );
  }
}