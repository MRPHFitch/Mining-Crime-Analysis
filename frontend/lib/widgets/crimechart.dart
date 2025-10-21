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

Widget buildAprioriTable(List aprioriRules) {
  return DataTable(
    columns: const [
      DataColumn(label: Text('Antecedents')),
      DataColumn(label: Text('Consequents')),
      DataColumn(label: Text('Support')),
      DataColumn(label: Text('Confidence')),
      DataColumn(label: Text('Lift')),
    ],
    rows: aprioriRules.map<DataRow>((rule) {
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