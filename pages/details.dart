import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class Details extends StatefulWidget {
  final String id;

  const Details(this.id, {Key? key}) : super(key: key);

  @override
  State<Details> createState() => _DetailsState();
}

class _DetailsState extends State<Details> {
  List<FlSpot> chartData = [];
  String name = '';
  String location = '';
  String gasName = '';
  Timestamp? startTime;
  Timestamp? endTime;

  FlSpot? tappedSpot; // To store the tapped spot

  @override
  void initState() {
    super.initState();
    fetchData(); // Fetch Firestore data when the page loads
  }

  void fetchData() {
    FirebaseFirestore.instance
        .collection('devices')
        .doc(widget.id)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        // Retrieve name, location, gas name, start time, and end time
        setState(() {
          name = snapshot['name'] ?? '';
          location = snapshot['location'] ?? '';
          gasName = snapshot['gasName'] ?? '';

          // Ensure startTime and endTime are of type Timestamp
          startTime = snapshot['startTime'] as Timestamp?;
          endTime = snapshot['endTime'] as Timestamp?;

          // Fetching data from the 'data' sub-collection
          fetchSubCollectionData();
        });
      }
    });
  }

  void fetchSubCollectionData() {
    FirebaseFirestore.instance
        .collection('devices')
        .doc(widget.id)
        .collection('data')
        .orderBy('timestamp') // Order by timestamp
        .snapshots()
        .listen((querySnapshot) {
      List<FlSpot> spots = [];
      for (var doc in querySnapshot.docs) {
        var data = doc['data'] as List<dynamic>;
        var timestamp = doc['timestamp'];

        // Check if timestamp is of type Timestamp, then convert
        if (timestamp is Timestamp) {
          // Convert values to double and create FlSpot
          for (var value in data) {
            spots.add(FlSpot(
              timestamp.millisecondsSinceEpoch.toDouble(),
              double.tryParse(value.toString()) ?? 0.0,
            ));
          }
        }
      }
      setState(() {
        chartData = spots; // Update chart data in real-time
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade900, // Dark blue for app bar
        title: Text(
          "Details for $name",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.white),
            onPressed: editData,
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.white),
            onPressed: deleteData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chart for data visualization
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: chartData.isNotEmpty
                    ? GestureDetector(
                  onTapDown: (details) {
                    final renderBox = context.findRenderObject() as RenderBox;
                    final localPosition = renderBox.globalToLocal(details.globalPosition);
                    final touchedValue = getTouchedValue(localPosition);
                    if (touchedValue != null) {
                      setState(() {
                        tappedSpot = touchedValue;
                      });
                    }
                  },
                  child: LineChart(
                    LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                          spots: chartData,
                          isCurved: false,
                          color: Colors.cyan,
                          barWidth: 2,
                        ),
                      ],
                      titlesData: FlTitlesData(
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 5 * 60 * 1000,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                DateFormat('mm').format(DateTime.fromMillisecondsSinceEpoch(value.toInt())),
                                style: TextStyle(color: Colors.black),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: true),
                    ),
                  ),
                )
                    : Center(
                  child: Text(
                    "No chart data available.",
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Displaying data in a Card widget
            Card(
              color: Colors.blue.shade50,
              elevation: 4.0,
              margin: const EdgeInsets.only(bottom: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Name: $name",
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      "Location: $location",
                      style: TextStyle(fontSize: 16.0, color: Colors.blueGrey.shade700),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      "Gas Name: $gasName",
                      style: TextStyle(fontSize: 16.0, color: Colors.blueGrey.shade700),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      "Start Time: ${startTime?.toDate().toLocal() ?? 'N/A'}",
                      style: TextStyle(fontSize: 16.0, color: Colors.blueGrey.shade700),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      "End Time: ${endTime?.toDate().toLocal() ?? 'N/A'}",
                      style: TextStyle(fontSize: 16.0, color: Colors.blueGrey.shade700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (tappedSpot != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Data: ${tappedSpot?.y.toStringAsFixed(2)} at ${DateTime.fromMillisecondsSinceEpoch(tappedSpot!.x.toInt()).toLocal()}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                ),
              ),
          ],
        ),
      ),
    );
  }

  FlSpot? getTouchedValue(Offset localPosition) {
    double closestDistance = double.infinity;
    FlSpot? closestSpot;

    for (var spot in chartData) {
      final spotX = spot.x.toInt();
      final distance = (localPosition.dx - spotX).abs();

      if (distance < closestDistance) {
        closestDistance = distance;
        closestSpot = spot;
      }
    }

    return closestDistance < 20 ? closestSpot : null;
  }

  void editData() {
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController(text: name);
        final locationController = TextEditingController(text: location);
        final gasNameController = TextEditingController(text: gasName);

        return AlertDialog(
          backgroundColor: Colors.blue.shade900, // Dark blue background
          title: Text("Edit Data", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Name",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              TextField(
                controller: locationController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Location",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              TextField(
                controller: gasNameController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Gas Name",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                FirebaseFirestore.instance
                    .collection('devices')
                    .doc(widget.id)
                    .update({
                  'name': nameController.text,
                  'location': locationController.text,
                  'gasName': gasNameController.text,
                }).then((_) {
                  Navigator.of(context).pop();
                  fetchData(); // Refresh data
                });
              },
              child: Text("Save", style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancel", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void deleteData() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Confirm Deletion"),
          content: Text("Are you sure you want to delete all data associated with this device? This will also delete all chart data."),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  // Panggil fungsi untuk menghapus dokumen utama beserta sub-collectionnya
                  await deleteDocumentWithSubCollections(widget.id);

                  // Setelah selesai menghapus, tutup dialog dan kembali ke halaman sebelumnya
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Go back to the previous screen
                } catch (e) {
                  print("Error deleting document: $e");
                  Navigator.of(context).pop(); // Close dialog on error
                }
              },
              child: Text("Delete"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  Future<void> deleteDocumentWithSubCollections(String docId) async {
    final docRef = FirebaseFirestore.instance.collection('devices').doc(docId);

    // Panggil fungsi untuk menghapus sub-collection terlebih dahulu
    await deleteSubCollections(docRef);

    // Hapus dokumen utama setelah sub-collection dihapus
    await docRef.delete();
  }

  Future<void> deleteSubCollections(DocumentReference docRef) async {
    final subCollectionRef = docRef.collection('data');

    final subCollectionSnapshot = await subCollectionRef.get();

    // Gunakan batch untuk menghapus semua dokumen dalam sub-collection
    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (var doc in subCollectionSnapshot.docs) {
      batch.delete(doc.reference); // Tambahkan setiap dokumen ke batch delete
    }

    // Commit batch untuk menghapus dokumen
    await batch.commit();
  }



}
