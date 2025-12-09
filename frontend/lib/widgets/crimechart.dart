import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

// Helper function to map category values to readable strings and truncate if too long
String mapCategoryValue(dynamic value, String key) {
  if (key == 'weapon_used') {
    if (value == 0) return 'No Weapon'; // More concise for chart labels
    if (value == 1) return 'Weapon Used';
  }
  String label = value.toString();
  // Truncate long labels for better readability in grouped charts
  if (label.length > 25) {
    return '${label.substring(0, 20)}...';
  }
  return label;
}

/// Generic Crime Bar Chart Widget
Widget buildCrimeBarChart(BuildContext context, List dataList, {required String categoryKey, int maxCategoriesToShow = 10}) {
  if (dataList.isEmpty) {
    return const Text('No data available.');
  }

  // Define a consistent order and color for seasons
  final List<String> orderedSeasons = ['Winter', 'Spring', 'Summer', 'Fall'];
  final Map<String, Color> seasonColors = {
    'Winter': Colors.lightBlue.shade300,
    'Spring': Colors.lightGreen.shade300,
    'Summer': Colors.orange.shade300,
    'Fall': Colors.brown.shade300,
  };

  // Group counts by category and then by season
  // Map<CategoryName, Map<SeasonName, Count>>
  final Map<String, Map<String, double>> countsPerCategoryPerSeason = {};
  for (var item in dataList) {
    final category = mapCategoryValue(item[categoryKey], categoryKey);
    final season = item['season'] as String;
    final count = (item['count'] ?? 0) as int;

    countsPerCategoryPerSeason.putIfAbsent(category, () => {});
    countsPerCategoryPerSeason[category]!.update(season, (value) => value + count, ifAbsent: () => count.toDouble());
  }

  // Calculate total counts per category across ALL seasons to find top N categories
  final Map<String, double> totalCountsPerCategory = {};
  countsPerCategoryPerSeason.forEach((category, seasonCounts) {
    totalCountsPerCategory[category] = seasonCounts.values.fold(0.0, (sum, count) => sum + count);
  });

  // Sort categories by total count and take the top N
  final sortedCategoryEntries = totalCountsPerCategory.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final displayedCategoryNames = sortedCategoryEntries.take(maxCategoriesToShow).map((e) => e.key).toList();

  final List<BarChartGroupData> barGroups = [];
  double maxGroupTotal = 0;
  final double barWidth = 8; // Width of each individual bar within a group
  final double barsSpace = 2; // Space between bars within a group
  final double groupSpace = 20; // Space between groups of bars

  for (int i = 0; i < displayedCategoryNames.length; i++) {
    final categoryName = displayedCategoryNames[i];
    final Map<String, double> seasonCounts = countsPerCategoryPerSeason[categoryName] ?? {};

    final List<BarChartRodData> rods = [];
    double groupTotal = 0;

    // Create a bar for each season within this category, in consistent order
    for (var season in orderedSeasons) {
      final countForSeason = seasonCounts[season] ?? 0.0;
      rods.add(
        BarChartRodData(
          toY: countForSeason,
          color: seasonColors[season],
          width: barWidth,
          borderRadius: BorderRadius.circular(2),
        ),
      );
      groupTotal += countForSeason;
    }

    barGroups.add(
      BarChartGroupData(
        x: i, // X-axis position for this group
        barRods: rods,
        barsSpace: barsSpace, // Space between rods in a group
        groupVertically: false, // Ensure bars are side-by-side
      ),
    );
    if (groupTotal > maxGroupTotal) {
      maxGroupTotal = groupTotal;
    }
  }
  
  // Determine max Y value for the chart's axis
  double maxY = maxGroupTotal * .275; // Add some padding

  // Calculate the required width for the chart to accommodate all groups and bars
  double chartContentWidth = (displayedCategoryNames.length * (orderedSeasons.length * barWidth + 
  (orderedSeasons.length - 1) * barsSpace)) + (displayedCategoryNames.length - 1) * groupSpace;
  // Add some extra padding to the content width
  chartContentWidth += 50; 
  
  return Column(
    children: [
      // Legend for seasons
      Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Wrap(
          spacing: 12.0,
          runSpacing: 4.0,
          children: orderedSeasons.map((season) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                color: seasonColors[season],
              ),
              const SizedBox(width: 4),
              Text(season, style: const TextStyle(fontSize: 12)),
            ],
          )).toList(),
        ),
      ),
      SizedBox(
        height: 500, // Increased height for more space for labels and chart
        width: MediaQuery.of(context).size.width, // Take full width initially
        child: SingleChildScrollView( // Allow horizontal scrolling if bars get too wide
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: chartContentWidth > MediaQuery.of(context).size.width
                   ? chartContentWidth : MediaQuery.of(context).size.width, // Ensure width is at least screen width or calculated content width
            child: Padding( // Add padding around the chart itself
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
                          if (value.toInt() >= 0 &&
                              value.toInt() < displayedCategoryNames.length) {
                            return SideTitleWidget(
                              meta: meta,
                              space: 15, // space between labels and axis
                              child: SizedBox(
                                width: 100, // adjust width for wrapping
                                child: Text(
                                  displayedCategoryNames[value.toInt()],
                                  style: const TextStyle(fontSize: 12),
                                  softWrap: true, // allow wrapping
                                  textAlign: TextAlign
                                      .center, // center the wrapped text
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                        interval: 1, // Show every label
                        reservedSize: 80, // Increased reserved space for rotated labels
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (maxY / 5).ceilToDouble(), // Dynamic interval for Y-axis
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            meta: meta,
                            space: 10,
                            child: Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 12), // Increased font size
                            ),
                          );
                        },
                        reservedSize: 40, // Ensure enough space for Y-axis labels
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: true, drawVerticalLine: false), // Show horizontal grid for readability
                  borderData: FlBorderData(show: false), // Hide border
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipPadding: const EdgeInsets.all(8),
                      tooltipMargin: 8,
                      getTooltipColor: (group) => Colors.blueGrey, // NEW way to set bg color,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final category = displayedCategoryNames[group.x.toInt()];
                        final season = orderedSeasons[rodIndex];
                        final count = rod.toY.toInt();
                        return BarTooltipItem(
                          '$category\n',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          children: <TextSpan>[
                            TextSpan(
                              text: '$season: $count',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
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
            color: metric == 'lift' ? Colors.cyan : Colors.purple[400], // Different color for lift/confidence
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
    height: 400, // Adjust height as needed
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
                  if (value.toInt() >= 0 &&
                      value.toInt() < topRulesChart.length) {
                    final ruleLabel =
                        topRulesChart[value.toInt()]['rule'] as String;
                    return SideTitleWidget(
                      meta: meta,
                      space: 8,
                      child: SizedBox(
                        width: 100, // ← adjust until labels wrap nicely
                        child: Text(
                          ruleLabel,
                          style: const TextStyle(fontSize: 10),
                          softWrap: true,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
                interval: 1,
                reservedSize: 150, // More space for rule labels
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (maxY / 4).ceilToDouble(), // Show 4-5 labels on Y-axis
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(2), // Show value with 2 decimal places
                    style: const TextStyle(fontSize: 12),
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

/// Generic heatmap widget
Widget buildGenericHeatmap({
  required List<Map<String, dynamic>> data,
  required String primaryKey, // e.g., 'season'
  required String valueMapKey, // e.g., 'crime_counts' or 'weapon_counts'
  String? title,
  double maxColorValue = 1000, // Default max value; adjust based on your data's actual max counts
  Color baseColor = Colors.cyan,
}) {
  if (data.isEmpty) {
    return const Text("No data available.");
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
                      child: Text(
                        colLabel.length > 25 ? '${colLabel.substring(0, 20)}...' : colLabel,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
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