import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SequencesPage extends StatefulWidget {
  const SequencesPage({super.key});

  @override
  State<SequencesPage> createState() => _SequencesPageState();
}

class _SequencesPageState extends State<SequencesPage> {
  final TextEditingController _minSupportController = TextEditingController(text: '0.01');
  final TextEditingController _timeWindowController = TextEditingController(text: '24');
  
  final List<String> _groupingMethods = ['spatial_temporal', 'temporal_only', 'area_based'];
  String _selectedGroupingMethod = 'spatial_temporal'; // Default value

  bool _isLoading = false;
  Map<String, dynamic>? _sequencesResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // No initial fetch here; it will be triggered by the button
  }

  @override
  void dispose() {
    _minSupportController.dispose();
    _timeWindowController.dispose();
    super.dispose();
  }

  Future<void> _runSequenceMining() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _sequencesResult = null; // Clear previous results
    });

    final double? minSupport = double.tryParse(_minSupportController.text);
    final int? timeWindowHours = int.tryParse(_timeWindowController.text);

    if (minSupport == null || minSupport <= 0 || minSupport > 1) {
      setState(() {
        _errorMessage = 'Please enter a valid min. support (0.001 - 1.0).';
        _isLoading = false;
      });
      return;
    }
    if (timeWindowHours == null || timeWindowHours <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid time window in hours (positive integer).';
        _isLoading = false;
      });
      return;
    }

    try {
      final url = Uri.parse("http://127.0.0.1:8000/api/crime_sequences");
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'min_support': minSupport,
          'time_window_hours': timeWindowHours,
          'grouping_method': _selectedGroupingMethod,
          // 'area_col' can be added here if 'area_based' is selected and a specific column is desired
          // For now, let the backend handle the default 'area_name' for 'area_based'
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _sequencesResult = data;
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
          _errorMessage = "Failed to fetch crime sequences: ${response.statusCode} - $errorDetail";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error connecting to the server: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recurring Crime Sequences")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'Min. Support Threshold',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: SizedBox(
                width: 70.0,
                child: TextField(
                  controller: _minSupportController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: '0.01',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Time Window (hours)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: SizedBox(
                width: 70.0,
                child: TextField(
                  controller: _timeWindowController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: '24',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Grouping Method',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: DropdownButton<String>(
                value: _selectedGroupingMethod,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedGroupingMethod = newValue!;
                  });
                },
                items: _groupingMethods.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  side: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                ),
                onPressed: _isLoading ? null : _runSequenceMining,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Run Sequence Mining'),
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  'Error: $_errorMessage',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 24),
            // Display results only if they are available
            if (_sequencesResult != null)
              Expanded(
                child: _sequencesResult!['patterns'] == null || (_sequencesResult!['patterns'] as List).isEmpty
                    ? const Center(child: Text("No frequent sequences found with current parameters."))
                    : ListView.builder(
                        itemCount: (_sequencesResult!['patterns'] as List).length,
                        itemBuilder: (context, index) {
                          final pattern = (_sequencesResult!['patterns'] as List)[index];
                          final crimes = (pattern["pattern"] as List).join(" → ");
                          final support = pattern["support_pct"];

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(crimes),
                              subtitle: Text("Support: $support%"),
                            ),
                          );
                        },
                      ),
              ),
            // Message when no results yet
            if (!_isLoading && _sequencesResult == null && _errorMessage == null)
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Enter parameters and press "Run Sequence Mining" to see results.'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}