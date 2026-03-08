import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_database/firebase_database.dart';

class StudentQRScanner extends StatefulWidget {
  const StudentQRScanner({super.key});

  @override
  State<StudentQRScanner> createState() => _StudentQRScannerState();
}

class _StudentQRScannerState extends State<StudentQRScanner> {
  final DatabaseReference attendanceRef = FirebaseDatabase.instance.ref(
    "attendance",
  );

  bool scanned = false;

  void saveAttendance(String tripId) {
    attendanceRef.push().set({
      "studentId": "student1",
      "tripId": tripId,
      "time": DateTime.now().toString(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Attendance Marked Successfully")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Bus QR")),
      body: MobileScanner(
        onDetect: (BarcodeCapture capture) {
          if (scanned) return;

          final List<Barcode> barcodes = capture.barcodes;

          for (final barcode in barcodes) {
            final String? code = barcode.rawValue;

            if (code != null) {
              scanned = true;

              saveAttendance(code);

              Navigator.pop(context);

              break;
            }
          }
        },
      ),
    );
  }
}
