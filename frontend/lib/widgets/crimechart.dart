// Filepath: /Users/Phoo/Classes/Data Mining/Project/Mining-Crime-Analysis/frontend/lib/widgets/crimechart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

// Helper function to map category values to readable strings (kept for consistency, defined in chart widget scope)
String mapCategoryValue(dynamic value, String key) {
  if (key == 'weapon_used') {
    if (value == 0) return 'No Weapon Used';
    if (value == 1) return 'Weapon Used';
  }
  return value.toString();
}

/// Generic Crime Bar Chart Widget
Widget buildCrimeBarChart(List dataList, {required String categoryKey, int maxCategories = 5}) {
  if (dataList.isEmpty) {
    return Text('No data available for $categoryKey.');
  }

  final seasons = dataList.map((e) => e['season']).toSet().toList();
  // Calculate total counts per category across all seasons
  final Map<String, double> totalCountsPerCategory = {};
  for (var item in dataList) {
    final category = mapCategoryValue(item[categoryKey], categoryKey);
    final count = (item['count'] as int).toDouble();
    totalCountsPerCategory.update(category, (value) => value + count, ifAbsent: () => count);
  }

  // Sort categories by total count and take the top N
  final sortedCategories = totalCountsPerCategory.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final displayedCategories = sortedCategories.take(maxCategories).map((e) => e.key).toList();

  // Prepare BarChartGroupData for only the displayed categories
  final List<BarChartGroupData> barGroups = [];
  for (int i = 0; i < displayedCategories.length; i++) {
    final category = displayedCategories[i];
    final totalCount = totalCountsPerCategory[category] ?? 0;

    barGroups.add(
      BarChartGroupData(
        x: i, // Use index as X value
        barRods: [
          BarChartRodData(
            toY: totalCount,
            color: Colors.blueAccent, // Customize bar color
            width: 25, // Increased bar width for better visibility
            borderRadius: BorderRadius.circular(4),
          ),
        ],
        // showingTooltipIndicators: [0], // Uncomment if you want tooltips, but might clutter small charts
      ),
    );
  }
  
  // Determine max Y value for the chart's axis
  double maxY = totalCountsPerCategory.values.isEmpty ? 0 : totalCountsPerCategory.values.reduce(
      (curr, next) => curr > next ? curr : next
  ) * 1.2; // Add some padding

  return SizedBox(
    height: 1000, // Increased height for more space
    child: BarChart(
      BarChartData(
        barGroups: barGroups,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                // Display category names on the bottom axis
                if (value.toInt() >= 0 && value.toInt() < displayedCategories.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 25.0), // Increased padding
                    child: RotatedBox(
                      quarterTurns: -1, // Rotate labels if they are long
                      child: Text(
                        displayedCategories[value.toInt()],
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  );
                }
                return const Text('');
              },
              interval: 1, // Show every label
              reservedSize: 200, // Increased reserved space for labels
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (maxY / 5).ceilToDouble(), // Show 5 labels on Y-axis
              getTitlesWidget: (value, meta) {
                return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false), // Hide grid lines
        borderData: FlBorderData(show: false), // Hide border
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
      ),
    ),
  );
}

Widget buildAprioriRulesBarChart(List topRulesChart, {required String metric}) {
  if (topRulesChart.isEmpty){
    return const Text('No top rules data available.');
  }
  if (metric != 'lift' && metric != 'confidence'){
    return const Text('Invalid metric for Apriori rules chart. Choose "lift" or "confidence".');
  }
  final List<BarChartGroupData> barGroups = [];
  double maxY = 0;

  for (int i = 0; i < topRulesChart.length; i++) {
    final rule = topRulesChart[i];
    final value = (rule[metric] as num).toDouble();
    
    if (value > maxY) {
      maxY = value;
    }

    barGroups.add(
      BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: value,
            color: metric == 'lift' ? Colors.green[400] : Colors.purple[400], // Different color for lift/confidence
            width: 15,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
        // showingTooltipIndicators: [0], // Uncomment if you want tooltips
      ),
    );
  }
  maxY *= 1.2; // Add some padding to maxY

  return SizedBox(
    height: 350, // Adjust height as needed
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
      child: BarChart(
        BarChartData(
          barGroups: barGroups,
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < topRulesChart.length) {
                    final ruleLabel = topRulesChart[value.toInt()]['rule'] as String;
                    return RotatedBox(
                      quarterTurns: -1, // Rotate labels
                      child: Text(
                        ruleLabel,
                        style: const TextStyle(fontSize: 10), // Slightly smaller font for rules
                      ),
                       );
                  }
                  return const Text('');
                },
                interval: 1,
                reservedSize: 100, // More space for rule labels
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (maxY / 4).ceilToDouble(), // Show 4-5 labels on Y-axis
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(2), // Show value with 2 decimal places
                    style: const TextStyle(fontSize: 10),
                  );
                },
                reservedSize: 40,
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
        ),
      ),
    ),
  );
}

/// Generic heatmap widget (kept as placeholder)
Widget buildGenericHeatmap({
  required List<Map<String, dynamic>> data,
  required String primaryKey, // e.g., 'season'
  required String valueMapKey, // e.g., 'crime_counts' or 'weapon_counts'
  String? title,
  double maxColorValue = 1000, // Default max value; adjust based on your data's actual max counts
}) {
  if (data.isEmpty) {
    return const Text("No data available for heatmap.");
  }

  // Extract all unique row and column labels
  final List<String> rowLabels = data.map((e) => e[primaryKey] as String).toList()..sort();
  Set<String> allColLabelsSet = {};
  for (var row in data) {
    (row[valueMapKey] as Map<String, dynamic>).keys.forEach((key) => allColLabelsSet.add(key));
  }
  final List<String> colLabels = allColLabelsSet.toList()..sort();
  // Create a 2D array/map for easy lookup of values
  final Map<String, Map<String, int>> values = {};
  int currentDataMaxVal = 0; // Track max value in the actual data
  for (var row in data) {
    final rowName = row[primaryKey] as String;
    values[rowName] = {};
    (row[valueMapKey] as Map<String, dynamic>).forEach((colName, count) {
      values[rowName]![colName] = count as int;
      if (count > currentDataMaxVal) {
        currentDataMaxVal = count;
      }
    });
  }
  // Dynamically adjust maxColorValue if the data's max is higher than the provided/default
  if (currentDataMaxVal > maxColorValue) {
    maxColorValue = currentDataMaxVal.toDouble();
  }
  // Build the heatmap using a Column of Rows
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (title != null) ...[
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
      ],
      SingleChildScrollView( // Allow horizontal scrolling for wide heatmaps
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row (column labels)
            Row(
              children: [
                const SizedBox(width: 100), // Space for row labels
                ...colLabels.map((colLabel) => SizedBox(
                  width: 80, // Cell width
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: -1,
                      child: Text(
                        colLabel.length > 15 ? '${colLabel.substring(0, 12)}...' : colLabel,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ),
                )).toList(),
              ],
            ),
            const Divider(height: 1, thickness: 1),
            // Data Rows
            ...rowLabels.map((rowLabel) {
              return Row(
                children: [
                  SizedBox(
                    width: 100, // Space for row labels
                    child: Text(
                      rowLabel,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                      ),
                  ),
                  ...colLabels.map((colLabel) {
                    final count = values[rowLabel]?[colLabel] ?? 0;
                    // Scale color based on count
                    final double normalizedCount = count / maxColorValue;
                    final Color cellColor = Color.lerp(Colors.white, Colors.red[700], normalizedCount)!;

                    return Container(
                      width: 80,
                      height: 30, // Cell height
                      decoration: BoxDecoration(
                        color: cellColor,
                        border: Border.all(color: Colors.grey[300]!, width: 0.5),
                      ),
                      child: Center(
                        child: Text(
                          count.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: normalizedCount > 0.6 ? Colors.white : Colors.black, // Text color for contrast
                          ),
                          ),
                      ),
                    );
                  }).toList(),
                ],
              );
            }).toList(),
            ],
        ),
      ),
    ],
  );
}

Widget buildAprioriTable(List aprioriRules, {bool showOnlyTop5 = false}) {
  final displayRules = showOnlyTop5 ? aprioriRules.take(5).toList() : aprioriRules;

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