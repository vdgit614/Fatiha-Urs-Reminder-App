import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  const AndroidInitializationSettings initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings = InitializationSettings(android: initAndroid);
  await flutterLocalNotificationsPlugin.initialize(initSettings);
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: HomeScreen()));
}

class FullArchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    double w = size.width;
    double h = size.height;
    Path path = Path();
    path.moveTo(w / 2, 0);
    path.cubicTo(w * 0.65, h * 0.08, w, h * 0.18, w, h * 0.30);
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.lineTo(0, h * 0.30);
    path.cubicTo(0, h * 0.18, w * 0.35, h * 0.08, w / 2, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

class FullArchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double w = size.width;
    double h = size.height;
    Path path = Path();
    path.moveTo(w / 2, 0);
    path.cubicTo(w * 0.65, h * 0.08, w, h * 0.18, w, h * 0.30);
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.lineTo(0, h * 0.30);
    path.cubicTo(0, h * 0.18, w * 0.35, h * 0.08, w / 2, 0);
    path.close();
    canvas.drawShadow(path, Colors.black26, 10, true);
    Paint fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    Paint border = Paint()
      ..color = Color(0xFF0F4D24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> reminders = [];

  @override
  void initState() {
    super.initState();
    loadReminders();
    requestPerm();
  }

  Future<void> requestPerm() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> loadReminders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('reminders');
    if (data != null) {
      setState(() {
        reminders = List<Map<String, dynamic>>.from(json.decode(data));
      });
    }
  }

  Future<void> saveReminders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('reminders', json.encode(reminders));
  }

  Future<void> scheduleNotif(int id, String title, DateTime dt) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'Fatiha Urs Reminder',
      '$title - आज है',
      tz.TZDateTime.from(dt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'fatiha_urs_channel',
          'Fatiha Urs',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> addDialog(String type) async {
    TextEditingController ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('$type का नाम'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: 'जैसे: दादा जान का $type'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.isEmpty) return;
              DateTime? d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
              if (d == null) return;
              TimeOfDay? t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: 6, minute: 0));
              if (t == null) return;
              DateTime finalDt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
              int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
              setState(() {
                reminders.add({'id': id, 'name': '$type: ${ctrl.text}', 'date': finalDt.toIso8601String()});
              });
              await saveReminders();
              await scheduleNotif(id, '$type: ${ctrl.text}', finalDt);
              Navigator.pop(c);
            },
            child: Text('Set'),
          ),
        ],
      ),
    );
  }

  Widget rowItem(String n, String t) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 80, child: Text(n, textAlign: TextAlign.right, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F4D24)))),
          SizedBox(width: 12),
          Text(t, style: TextStyle(fontSize: 16, color: Color(0xFF0F4D24))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double sw = MediaQuery.of(context).size.width;
    double sh = MediaQuery.of(context).size.height;
    String engDate = "${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().year}";

    return Scaffold(
      backgroundColor: Color(0xFFF2F7F2),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                child: CustomPaint(
                  painter: FullArchPainter(),
                  child: ClipPath(
                    clipper: FullArchClipper(),
                    child: Container(
                      width: sw,
                      height: sh * 0.85,
                      child: Column(
                        children: [
                          SizedBox(height: sh * 0.12),
                          Text("JAMADIL AWAL", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F4D24))),
                          SizedBox(height: 14),
                          Text("08 - 05 - 1448", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F4D24))),
                          SizedBox(height: 28),
                          Text("English Date: $engDate", style: TextStyle(fontSize: 13, color: Colors.grey)),
                          SizedBox(height: 10),
                          Divider(indent: 50, endIndent: 50, thickness: 1, color: Color(0xFF0F4D24)),
                          SizedBox(height: 10),
                          Text("NAMAZ TIME RANGE", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F4D24))),
                          SizedBox(height: 20),
                          rowItem("Fajr", "05:00 - 06:30"),
                          rowItem("Zuhr", "12:30 - 15:15"),
                          rowItem("Asr", "15:15 - 17:50"),
                          rowItem("Maghrib", "18:35 - 19:40"),
                          rowItem("Isha", "19:40 - 04:59"),
                          Spacer(),
                          Padding(
                            padding: EdgeInsets.fromLTRB(12, 0, 12, 22),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: () => addDialog('Fatiha'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0F4D24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                      child: Text("+ Add Fatiha", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: SizedBox(
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: () => addDialog('Urs'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, side: BorderSide(color: Color(0xFF0F4D24), width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                      child: Text("+ Add Urs", style: TextStyle(color: Color(0xFF0F4D24), fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
