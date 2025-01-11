import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:uuid/uuid.dart';
import 'dart:typed_data';


class BluetoothScanPage extends StatefulWidget {
  @override
  _BluetoothScanPageState createState() => _BluetoothScanPageState();
}

class _BluetoothScanPageState extends State<BluetoothScanPage> {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  List<ScanResult> scanResults = [];
  bool isScanning = false;
  BluetoothDevice? connectedDevice;
  List<int> receivedData = [];
  String? currentDocumentId;
  String name = "Nama Karyawan";
  String location = "Lokasi Karyawan";
  String gasName = "Nama Gas"; // Gas name for the document
  Timestamp? startTime;
  Timestamp? endTime;

  // Data chart
  List<FlSpot> chartData = [];

  @override
  void initState() {
    super.initState();
    startScan();
  }

  void startScan() {
    setState(() {
      isScanning = true;
    });

    flutterBlue.startScan(timeout: Duration(seconds: 5));

    flutterBlue.scanResults.listen((results) {
      setState(() {
        scanResults = results;
      });
    }).onDone(() {
      setState(() {
        isScanning = false;
      });
    });
  }

  void connectToDevice(BluetoothDevice device) async {
    setState(() {
      connectedDevice = device;
      currentDocumentId = Uuid().v4(); // Generate a new document ID
      startTime = Timestamp.now(); // Set start time when connecting
    });

    await device.connect();

    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.uuid.toString() == "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
          await characteristic.setNotifyValue(true);
          characteristic.value.listen((value) {
            if (value != null && value.length >= 2) { // Check if we have at least 2 bytes
              List<int> twoByteData = [];
              for (int i = 0; i < value.length - 1; i += 2) {
                int twoByteValue = ByteData.sublistView(Uint8List.fromList([value[i], value[i + 1]])).getInt16(0, Endian.little);
                twoByteData.add(twoByteValue);
              }
              setState(() {
                receivedData = twoByteData;
                addToChartData(twoByteData); // Add to chart
                if (startTime != null) {
                  sendDataToFirestore(twoByteData); // Send data to Firestore
                }
              });
            }
          });
        }
      }
    }
  }

  Future<void> sendDataToFirestore(List<int> data) async {
    if (currentDocumentId != null) {
      try {
        CollectionReference dataCollection = FirebaseFirestore.instance.collection('devices');

        await dataCollection.doc(currentDocumentId).set({
          'name': name,
          'location': location,
          'gasName': gasName,
          'startTime': startTime,
          'endTime': endTime,
        }, SetOptions(merge: true));

        String uuid = Uuid().v4();

        await dataCollection
            .doc(currentDocumentId)
            .collection('data')
            .doc(uuid)
            .set({
          'data': data.map((item) => item.toString()).toList(),
          'timestamp': Timestamp.now(),
        });

        print('Data successfully sent to Firestore: $data');
      } catch (e) {
        print('Failed to send data to Firestore: $e');
      }
    }
  }

  void addToChartData(List<int> data) {
    double time = DateTime.now().millisecondsSinceEpoch.toDouble();
    for (var value in data) {
      if (value.isFinite) {
        chartData.add(FlSpot(time, value.toDouble()));
        if (chartData.length > 50) {
          chartData.removeAt(0); // Remove old data if more than 50 points
        }
      }
    }
  }

  void disconnectFromDevice() async {
    if (connectedDevice != null) {
      endTime = Timestamp.now();
      await sendEndTimeToFirestore();
      await connectedDevice!.disconnect();
      setState(() {
        connectedDevice = null;
        receivedData = [];
      });
    }
  }

  Future<void> sendEndTimeToFirestore() async {
    if (currentDocumentId != null) {
      try {
        CollectionReference dataCollection = FirebaseFirestore.instance.collection('devices');
        await dataCollection.doc(currentDocumentId).update({
          'endTime': endTime,
        });
      } catch (e) {
        print('Failed to send end time to Firestore: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade900, // Dark blue theme for app bar
        title: Text('Scan Bluetooth Devices', style: TextStyle(color: Colors.white)),
        actions: [
          isScanning
              ? IconButton(icon: Icon(Icons.stop, color: Colors.white), onPressed: flutterBlue.stopScan)
              : IconButton(icon: Icon(Icons.search, color: Colors.white), onPressed: startScan),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: scanResults.length,
              itemBuilder: (context, index) {
                var result = scanResults[index];
                bool isConnected = connectedDevice != null && connectedDevice!.id == result.device.id;
                return Card(
                  color: Colors.blue.shade800, // Set card background to dark blue
                  margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: ListTile(
                    title: Text(
                      result.device.name.isEmpty ? "Unknown Device" : result.device.name,
                      style: TextStyle(color: Colors.white), // Set text color to white
                    ),
                    subtitle: Text(result.device.id.toString(), style: TextStyle(color: Colors.white70)),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        primary: isConnected ? Colors.red : Colors.green, // Red for disconnect, green for connect
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0), // Rounded button
                        ),
                      ),
                      child: Text(isConnected ? 'Disconnect' : 'Connect', style: TextStyle(color: Colors.white)),
                      onPressed: isConnected ? disconnectFromDevice : () => connectToDevice(result.device),
                    ),
                  ),
                );
              },
            ),
          ),
          if (connectedDevice != null && receivedData.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                height: 200,
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
                              style: TextStyle(color: Colors.white),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: true),
                  ),
                ),
              ),
            ),
          if (receivedData.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                color: Colors.blue.shade800, // Dark blue background for the card
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Data Terbaru: ${receivedData.toString()} PPB',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
