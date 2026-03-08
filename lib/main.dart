import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'driver_qr_screen.dart';
import 'student_qr_scanner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController idController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String errorText = '';

  void login() {
    String id = idController.text.trim();
    String pass = passwordController.text.trim();

    if (id == "student1" && pass == "1234") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StudentHome()),
      );
    } else if (id == "driver1" && pass == "1234") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DriverHome()),
      );
    } else if (id == "admin1" && pass == "1234") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminHome()),
      );
    } else {
      setState(() {
        errorText = "Invalid ID or Password";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Realtime Bus Tracking System",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            TextField(
              controller: idController,
              decoration: const InputDecoration(
                labelText: "User ID",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(onPressed: login, child: const Text("Login")),

            const SizedBox(height: 15),

            Text(errorText, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref("bus_location");

  GoogleMapController? mapController;

  LatLng busPosition = const LatLng(26.8467, 80.9462);

  Set<Marker> markers = {};
  Set<Polyline> polylines = {};

  LatLng? previousPosition;

  String etaText = "Waiting for bus...";
  String busStatus = "Waiting...";

  BitmapDescriptor? busIcon;

  @override
  void initState() {
    super.initState();

    BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/bus_icon.png',
    ).then((icon) {
      busIcon = icon;
    });

    drawRoute();
    listenBusLocation();
  }

  void drawRoute() {
    polylines.add(
      const Polyline(
        polylineId: PolylineId("route"),
        width: 5,
        color: Colors.blue,
        points: [
          LatLng(26.8467, 80.9462),
          LatLng(26.8500, 80.9500),
          LatLng(26.8550, 80.9600),
          LatLng(26.8600, 80.9700),
        ],
      ),
    );
  }

  void calculateETA(LatLng busPos) {
    double studentLat = 26.8467;
    double studentLng = 80.9462;

    double distance = Geolocator.distanceBetween(
      busPos.latitude,
      busPos.longitude,
      studentLat,
      studentLng,
    );

    double speed = 15;

    double timeSeconds = distance / speed;

    int minutes = (timeSeconds / 60).round();

    setState(() {
      etaText = "Bus arriving in $minutes minutes";
    });
  }

  void animateBus(LatLng newPosition) {
    if (previousPosition == null) {
      previousPosition = newPosition;
      return;
    }

    double latDiff = (newPosition.latitude - previousPosition!.latitude) / 10;

    double lngDiff = (newPosition.longitude - previousPosition!.longitude) / 10;

    for (int i = 1; i <= 10; i++) {
      Future.delayed(Duration(milliseconds: i * 60), () {
        LatLng intermediate = LatLng(
          previousPosition!.latitude + latDiff * i,
          previousPosition!.longitude + lngDiff * i,
        );

        setState(() {
          markers = {
            Marker(
              markerId: const MarkerId("bus"),
              position: intermediate,
              icon: busIcon ?? BitmapDescriptor.defaultMarker,
              infoWindow: const InfoWindow(title: "College Bus"),
            ),
          };
        });

        mapController?.animateCamera(CameraUpdate.newLatLng(intermediate));
      });
    }

    previousPosition = newPosition;
  }

  void listenBusLocation() {
    dbRef.onValue.listen((event) {
      if (!event.snapshot.exists) return;

      Map data = Map<String, dynamic>.from(event.snapshot.value as Map);

      double lat = data["latitude"];
      double lng = data["longitude"];
      String status = data["status"] ?? "Unknown";

      LatLng newPosition = LatLng(lat, lng);

      animateBus(newPosition);
      calculateETA(newPosition);

      setState(() {
        busStatus = status;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Bus Tracker"),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentQRScanner()),
              );
            },
          ),
        ],
      ),

      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: busPosition,
              zoom: 14,
            ),
            markers: markers,
            polylines: polylines,
            myLocationEnabled: true,
            onMapCreated: (controller) {
              mapController = controller;
            },
          ),

          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                etaText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),

          Positioned(
            top: 80,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "Bus Status: $busStatus",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DriverHome extends StatefulWidget {
  const DriverHome({super.key});

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  bool tripRunning = false;

  StreamSubscription<Position>? positionStream;

  GoogleMapController? mapController;

  LatLng currentPosition = const LatLng(26.8467, 80.9462);

  Set<Marker> markers = {};

  final DatabaseReference dbRef = FirebaseDatabase.instance.ref("bus_location");

  Future<void> startTrip() async {
    if (tripRunning) return;

    LocationPermission permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    setState(() {
      tripRunning = true;
    });

    positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 1,
          ),
        ).listen((Position position) {
          LatLng newPosition = LatLng(position.latitude, position.longitude);

          setState(() {
            currentPosition = newPosition;

            markers = {
              Marker(markerId: const MarkerId("bus"), position: newPosition),
            };
          });

          dbRef.set({
            "latitude": position.latitude,
            "longitude": position.longitude,
            "status": "Running",
            "time": DateTime.now().toString(),
          });

          mapController?.animateCamera(CameraUpdate.newLatLng(newPosition));
        });
  }

  void stopTrip() {
    positionStream?.cancel();
    positionStream = null;

    dbRef.update({"status": "Stopped"});

    setState(() {
      tripRunning = false;
    });
  }

  @override
  void dispose() {
    positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Driver Map Panel")),

      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: currentPosition,
          zoom: 15,
        ),
        markers: markers,
        myLocationEnabled: true,
        onMapCreated: (controller) {
          mapController = controller;
        },
      ),

      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "start",
            backgroundColor: Colors.green,
            onPressed: startTrip,
            child: const Icon(Icons.play_arrow),
          ),

          const SizedBox(height: 15),

          FloatingActionButton(
            heroTag: "stop",
            backgroundColor: Colors.red,
            onPressed: stopTrip,
            child: const Icon(Icons.stop),
          ),

          const SizedBox(height: 15),

          FloatingActionButton(
            heroTag: "qr",
            backgroundColor: Colors.blue,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DriverQRScreen(tripId: "BUS_TRIP_101"),
                ),
              );
            },
            child: const Icon(Icons.qr_code),
          ),
        ],
      ),
    );
  }
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final DatabaseReference attendanceRef = FirebaseDatabase.instance.ref(
    "attendance",
  );

  List attendanceList = [];

  @override
  void initState() {
    super.initState();
    loadAttendance();
  }

  void loadAttendance() {
    attendanceRef.onValue.listen((event) {
      if (!event.snapshot.exists) return;

      Map data = Map<String, dynamic>.from(event.snapshot.value as Map);

      List temp = [];

      data.forEach((key, value) {
        temp.add(value);
      });

      setState(() {
        attendanceList = temp;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Panel")),

      body: attendanceList.isEmpty
          ? const Center(
              child: Text(
                "No Attendance Records Yet",
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              itemCount: attendanceList.length,
              itemBuilder: (context, index) {
                var record = attendanceList[index];

                return Card(
                  margin: const EdgeInsets.all(10),
                  child: ListTile(
                    title: Text("Student: ${record["studentId"]}"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Trip: ${record["tripId"]}"),
                        Text("Time: ${record["time"]}"),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
