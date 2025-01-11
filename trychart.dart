import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SimpleLineChart extends StatelessWidget {
  final List<double> dataList; // List for chart data
  final List<Timestamp> timestamps; // List for timestamps

  SimpleLineChart(this.dataList, this.timestamps, {super.key}); // Updated constructor

  @override
  Widget build(BuildContext context) {
    // Convert timestamps to x-axis values (e.g., milliseconds since epoch)
    List<FlSpot> spots = [];
    for (int i = 0; i < dataList.length; i++) {
      spots.add(FlSpot(timestamps[i].millisecondsSinceEpoch.toDouble(), dataList[i]));
    }

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 2,
          ),
        ],
        titlesData: FlTitlesData(show: true),
        borderData: FlBorderData(show: true),
      ),
    );
  }
}
