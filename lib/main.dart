import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:adhan/adhan.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  try { tz.setLocalLocation(tz.getLocation('Asia/Kolkata')); } catch (_) {}
  const AndroidInitializationSettings initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  await flutterLocalNotificationsPlugin.initialize(const InitializationSettings(android: initAndroid));
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: HomeScreen()));
}

class FullArchClipper extends CustomClipper<Path> {
  @override Path getClip(Size size) {
    double w = size.width; double h = size.height;
    Path path = Path();
    path.moveTo(w / 2, 0);
    path.cubicTo(w * 0.65, h * 0.08, w, h * 0.18, w, h * 0.30);
    path.lineTo(w, h); path.lineTo(0, h * 0.30);
    path.cubicTo(0, h * 0.18, w * 0.35, h * 0.08, w / 2, 0);
    path.close(); return path;
  }
  @override bool shouldReclip(old) => false;
}

class FullArchPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size size) {
    double w = size.width; double h = size.height;
    Path path = Path();
    path.moveTo(w / 2, 0);
    path.cubicTo(w * 0.65, h * 0.08, w, h * 0.18, w, h * 0.30);
    path.lineTo(w, h); path.lineTo(0, h * 0.30);
    path.cubicTo(0, h * 0.18, w * 0.35, h * 0.08, w / 2, 0);
    path.close();
    canvas.drawShadow(path, Colors.black26, 10, true);
    Paint fill = Paint()..color = Colors.white..style = PaintingStyle.fill;
    Paint border = Paint()..color = Color(0xFF0F4D24)..style = PaintingStyle.stroke..strokeWidth = 6..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, fill); canvas.drawPath(path, border);
  }
  @override bool shouldRepaint(old) => false;
}

class HomeScreen extends StatefulWidget {
  @override _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late HijriCalendar todayHijri;
  List<Map<String, dynamic>> fatihaList = [];
  bool showFatihaList = false;
  List<String> hMonths = ["", "MUHARRAM", "SAFAR", "RABI-UL-AWWAL", "RABI-UL-AAKHAR", "JAMADIL AWAL", "JAMADIL AAKHAR", "RAJJAB", "SHABAN", "RAMZAN", "SHAWWAL", "ZIL-QAD", "ZIL-HAJJ"];
  String fajrRange = "--", zuhrRange = "--", asrRange = "--", maghribRange = "--", ishaRange = "--";

  @override void initState() {
    super.initState();
    todayHijri = getIslamicDate();
    calculateNamazRanges();
    loadData();
  }

  String format12(DateTime dt) {
    int h = dt.hour; String ampm = h >= 12 ? "PM" : "AM";
    int hour12 = h % 12; if (hour12 == 0) hour12 = 12;
    String m = dt.minute.toString().padLeft(2, '0');
    return "$hour12:$m $ampm";
  }

  void calculateNamazRanges() {
    try {
      final coords = Coordinates(23.0225, 72.5714);
      final params = CalculationMethod.karachi.getParameters();
      params.madhab = Madhab.hanafi;
      final prayerTimes = PrayerTimes.today(coords, params);
      setState(() {
        fajrRange = "${format12(prayerTimes
