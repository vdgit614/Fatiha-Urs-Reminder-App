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

final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  try { tz.setLocalLocation(tz.getLocation('Asia/Kolkata')); } catch (e) {}
  const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(const InitializationSettings(android: androidInit));
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: HomeScreen()));
}

class DomeClipper extends CustomClipper<Path> {
  @override Path getClip(Size size) {
    Path p = Path();
    p.moveTo(0, size.height);
    p.lineTo(0, size.height * 0.22);
    p.quadraticBezierTo(size.width * 0.5, 0, size.width, size.height * 0.22);
    p.lineTo(size.width, size.height);
    p.close();
    return p;
  }
  @override bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class HomeScreen extends StatefulWidget {
  @override State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late HijriCalendar todayHijri;
  List<Map<String, dynamic>> fatihaList = [];
  bool showList = false;
  List<String> hMonths = ["", "MUHARRAM","SAFAR","RABI-UL-AWWAL","RABI-UL-AAKHAR","JAMADIL AWAL","JAMADIL AAKHAR","RAJJAB","SHABAN","RAMZAN","SHAWWAL","ZIL-QAD","ZIL-HAJJ"];

  @override void initState() {
    super.initState();
    todayHijri = HijriCalendar.now();
    try { todayHijri.hDay = todayHijri.hDay - 1; } catch (e) {}
    loadData();
  }

  Future<void> loadData() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    if (pref.containsKey('fatiha_list')) {
      setState(() { fatihaList = List<Map<String, dynamic>>.from(json.decode(pref.getString('fatiha_list')!)); });
    }
  }
  Future<void> saveData() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    pref.setString('fatiha_list', json.encode(fatihaList));
  }
  int daysRemain(int d, int m) {
    int todayTotal = (todayHijri.hMonth - 1) * 30 + todayHijri.hDay;
    int targetTotal = (m - 1) * 30 + d;
    int diff = targetTotal - todayTotal;
    if (diff < 0) diff += 360;
    return diff;
  }

  Future<void> openAddDialog(String type) async {
    TextEditingController nameCtrl = TextEditingController();
    int selDay = todayHijri.hDay;
    int selMonth = todayHijri.hMonth;

    await showDialog(
      context: context,
      builder: (BuildContext ctx1) {
        return StatefulBuilder(
          builder: (BuildContext ctx2, StateSetter setD) {
            return AlertDialog(
              title: Text(type, style: TextStyle(color: Color(0xFF0F4D24), fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(labelText: 'add name here', hintText: 'add name here', border: OutlineInputBorder()),
                  ),
                  SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: DropdownButtonFormField<int>(value: selDay, decoration: InputDecoration(labelText: 'Day'), items: List.generate(30, (i) => DropdownMenuItem<int>(value: i+1, child: Text('${i+1}'))), onChanged: (v) { setD(() { selDay = v!; }); })),
                    SizedBox(width: 8),
                    Expanded(flex: 2, child: DropdownButtonFormField<int>(value: selMonth, decoration: InputDecoration(labelText: 'Month'), items: List.generate(12, (i) => DropdownMenuItem<int>(value: i+1, child: Text(hMonths[i+1], style: TextStyle(fontSize: 10)))), onChanged: (v) { setD(() { selMonth = v!; }); })),
                  ]),
                ]),
              ),
              actions: [
                TextButton(onPressed: () { Navigator.pop(ctx1); }, child: Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0F4D24)),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
                    Map<String, dynamic> item = {'id': id, 'name': nameCtrl.text.trim(), 'iDay': selDay, 'iMonth': selMonth, 'type': type};
                    int remain = daysRemain(selDay, selMonth);
                    for (int k = 0; k < 3; k++) {
                      int off = [7, 1, 0][k];
                      if (remain >= off) {
                        var when = tz.TZDateTime.now(tz.local).add(Duration(days: remain - off, hours: 8));
                        await plugin.zonedSchedule(id * 10 + k, item['name'], '${selDay} ${hMonths[selMonth]}', when, NotificationDetails(android: AndroidNotificationDetails('fatiha_channel', 'Fatiha', importance: Importance.high)), androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
                      }
                    }
                    setState(() { fatihaList.add(item); });
                    await saveData();
                    Navigator.pop(ctx1);
                  },
                  child: Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> shareList() async {
    if (fatihaList.isEmpty) return;
    String txt = 'MY FATIHA LIST\n\n';
    for (var r in fatihaList) { int d = daysRemain(r['iDay'], r['iMonth']); txt += "${r['name']} - ${r['iDay']} ${hMonths[r['iMonth']]} -> $d days\n"; }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/list.json');
      await file.writeAsString(json.encode(fatihaList));
      await Share.shareXFiles([XFile(file.path)], text: txt);
    } catch (e) { Share.share(txt); }
  }

  @override Widget build(BuildContext context) {
    String islamicDate = "${todayHijri.hDay.toString().padLeft(2,'0')} - ${todayHijri.hMonth.toString().padLeft(2,'0')} - ${todayHijri.hYear}";
    String engDate = "${DateTime.now().day.toString().padLeft(2,'0')}-${DateTime.now().month.toString().padLeft(2,'0')}-${DateTime.now().year}";
    return Scaffold(
      backgroundColor: Color(0xFFF2F7F2),
      body: Column(children: [
        Expanded(child: SingleChildScrollView(child: Container(
          width: double.infinity, height: 560,
          margin: EdgeInsets.all(6),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Color(0xFF0F4D24), width: 5), borderRadius: BorderRadius.circular(8)),
          child: ClipPath(
            clipper: DomeClipper(),
            child: Container(color: Colors.white, child: Column(children: [
              SizedBox(height: 50),
              Text(hMonths[todayHijri.hMonth], style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F4D24))),
              SizedBox(height: 10),
              Text(islamicDate, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF0F4D24))),
              SizedBox(height: 8),
              Text('English Date: $engDate', style: TextStyle(fontSize: 14, color: Colors.grey)),
              SizedBox(height: 10),
              Container(height: 1, width: 260, color: Color(0xFF0F4D24)),
              SizedBox(height: 14),
              Text('NAMAZ TIME RANGE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F4D24))),
              SizedBox(height: 18),
              Text('Fajr  05:25 - 06:40', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0F4D24))),
              SizedBox(height: 6),
              Text('Zuhr  12:25 - 16:30', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0F4D24))),
              SizedBox(height: 6),
              Text('Asr  16:30 - 18:07', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF
