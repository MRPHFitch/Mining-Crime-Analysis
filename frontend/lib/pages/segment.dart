import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math'; // For atan2 and pi

class SegmentPage extends StatefulWidget {
  const SegmentPage({super.key});

  @override
  _SegmentPageState createState() => _SegmentPageState();
}

class _SegmentPageState extends State<SegmentPage> {
  final TextEditingController _kController = TextEditingController(text: '5');
  bool _isLoading = false;
  Map<String, dynamic>? _kmeansResult;
  String? _errorMessage;

  @override
  void dispose() {
    _kController.dispose();
    super.dispose();
  }

  // Helper function to decode cyclical features (time and day of week)
  // This logic is mirrored from the `centroid_readable` function in `kmeans.py`.
  double _decodeCyclical(double sinVal, double cosVal, double period) {
    double angle = atan2(sinVal, cosVal);
    if (angle < 0) {
      angle += 2 * pi;
    }
    return (angle / (2 * pi)) * period;
  }

  Future<void> _runKMeans() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _kmeansResult = null;
    });

    final int? k = int.tryParse(_kController.text);
    if (k == null || k <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid positive integer for K.';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/hotspots'), // Your FastAPI backend URL
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'k': k,
          // Column names must match those in the cleaned dataset
          'datetime_col': 'date',
          'time_col': 'time',
          'lat_col': 'latitude',
          'lon_col': 'longitude',
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _kmeansResult = data;
        });
      } else {
        setState(() {
          // Attempt to parse error detail from FastAPI's HTTPException
          String errorDetail = 'Unknown error';
          try {
            final errorJson = json.decode(response.body);
            if (errorJson.containsKey('detail')) {
              errorDetail = errorJson['detail'];
            }
          } catch (_) {
            errorDetail = response.body; // Fallback to raw body
          }
          _errorMessage = 'Failed to run K-Means: ${response.statusCode} - $errorDetail';
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
      appBar: AppBar(title: const Text('Segment Crime on Time and Location')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'Number of Hot spots (K)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8), // Spacing between label and input box
            Center(
              child: SizedBox(
                width: 70.0, // Sets the width to fit a couple of digits
                child: TextField(
                  controller: _kController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center, // Centers the text within the field
                  decoration: const InputDecoration(
                    // labelText: 'Number of Hot spots (K)', // Removed labelText
                    hintText: '5', // Shorter hint for a compact field
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 10.0,
                      horizontal: 8.0,
                    ), // Compact padding
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  side: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                ),
                onPressed: _isLoading ? null : _runKMeans,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Run K-Means Clustering'),
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
            if (_kmeansResult != null)
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      'K-Means Hot spot Results',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text('Total records used for clustering: ${_kmeansResult!['n_rows_used']}'),
                    const SizedBox(height: 16),
                    Text(
                      'Cluster Counts:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    ...(_kmeansResult!['counts'] as Map<String, dynamic>).entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text('  Cluster ${entry.key}: ${entry.value} crimes'),
                      );
                    }),
                    const SizedBox(height: 16),
                    Text(
                      'Centroids (Hot spot Locations and Times):',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    ...(_kmeansResult!['centroids'] as List<dynamic>).map((centroid) {
                      final double hour = _decodeCyclical(centroid['hour_sin'], centroid['hour_cos'], 24);
                      final double dowValue = _decodeCyclical(centroid['dow_sin'], centroid['dow_cos'], 7);
                      final List<String> dowNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
                      final String dowLabel = dowNames[dowValue.round() % 7];

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Cluster ${centroid['cluster']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('  Latitude: ${centroid['latitude'].toStringAsFixed(5)}'),
                              Text('  Longitude: ${centroid['longitude'].toStringAsFixed(5)}'),
                              Text('  Approx. Time: ${hour.toStringAsFixed(1)}h (${dowLabel})'),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}