import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

Widget buildCrimeBarChart(List seasonCrime) {
  // Extract unique seasons and crime types
  final seasons = seasonCrime.map((e) => e['season']).toSet().toList();
  final crimeTypes = seasonCrime.map((e) => e['crime_type']).toSet().toList();

  // Build a map: {crimeType: [count for each season]}
  final Map<String, List<int>> dataMap = {
    for (var crime in crimeTypes)
      crime: [for (var season in seasons)
        seasonCrime.firstWhere(
          (e) => e['season'] == season && e['crime_type'] == crime,
          orElse: () => {'count': 0}
        )['count'] ?? 0
      ]
  };

  return SizedBox(
    height: 300,
    child: BarChart(
      BarChartData(
        barGroups: List.generate(seasons.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: List.generate(crimeTypes.length, (j) {
              return BarChartRodData(
                toY: dataMap[crimeTypes[j]]![i].toDouble(),
                color: Colors.primaries[j % Colors.primaries.length],
                width: 12,
              );
            }),
          );
        }),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text(seasons[value.toInt()]),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true),
          ),
        ),
        barTouchData: BarTouchData(enabled: true),
      ),
    ),
  );
}

Widget buildAprioriTable(List aprioriRules, {bool showOnlyTop5=false}) {
  final displayRules=showOnlyTop5
  ? aprioriRules.take(5).toList()
  : aprioriRules;

  return DataTable(
    columns: const [
      DataColumn(label: Text('Antecedents')),
      DataColumn(label: Text('Consequents')),
      DataColumn(label: Text('Support')),
      DataColumn(label: Text('Confidence')),
      DataColumn(label: Text('Lift')),
    ],
    rows: displayRules.map<DataRow>((rule) {
      return DataRow(cells: [
        DataCell(Text(rule['antecedents'].toString())),
        DataCell(Text(rule['consequents'].toString())),
        DataCell(Text(rule['support'].toStringAsFixed(2))),
        DataCell(Text(rule['confidence'].toStringAsFixed(2))),
        DataCell(Text(rule['lift'].toStringAsFixed(2))),
      ]);
    }).toList(),
  );
}

/// Generic heatmap widget
Widget buildGenericHeatmap({
  required List<Map<String, dynamic>> data,
  String? rowKey,             // optional if auto-detected
  String? valueMapKey,        // optional if auto-detected
  String? title,
  double maxColorValue = 50,  // adjust scaling intensity
  Color baseColor = Colors.cyan,
}) {
  if (data.isEmpty) {
    return const Text("No data available.");
  }

  // --- Infer keys if not specified ---
  final firstRow = data.first;
  final detectedRowKey = rowKey ?? firstRow.keys.firstWhere(
    (k) => k != 'values' && firstRow[k] is String,
    orElse: () => firstRow.keys.first,
  );

  final detectedValueMapKey = valueMapKey ?? firstRow.keys.firstWhere(
    (k) => firstRow[k] is Map<String, dynamic>,
    orElse: () => 'values',
  );

  // --- Build unique column headers ---
  final allColumns = data
      .expand((row) => (row[detectedValueMapKey] as Map<String, dynamic>).keys)
      .toSet()
      .toList();

  // --- Compute global max for color normalization ---
  final maxValue = data.fold<num>(
    0,
    (prev, row) => [
      prev,
      ...(row[detectedValueMapKey] as Map<String, dynamic>).values.cast<num>()
    ].reduce((a, b) => a > b ? a : b),
  );

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (title != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(label: Text(detectedRowKey.toUpperCase())),
            ...allColumns.map((col) => DataColumn(label: Text(col))),
          ],
          rows: data.map<DataRow>((row) {
            final values = row[detectedValueMapKey] as Map<String, dynamic>;
            return DataRow(cells: [
              DataCell(Text(row[detectedRowKey].toString())),
              ...allColumns.map((col) {
                final value = (values[col] ?? 0) as num;
                final intensity = (value / maxValue).clamp(0.1, 1.0);
                final color = baseColor.withOpacity(intensity.toDouble());
                return DataCell(
                  Container(
                    padding: const EdgeInsets.all(6),
                    color: color,
                    child: Text(
                      value.toString(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              }).toList(),
            ]);
          }).toList(),
        ),
      ),
    ],
  );
}
