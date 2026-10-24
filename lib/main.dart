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

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  try { tz.setLocalLocation(tz.getLocation('Asia/Kolkata')); } catch (_) {}
  const AndroidInitializationSettings initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  await flutterLocalNotificationsPlugin.initialize(const InitializationSettings(android: initAndroid));
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: HomeScreen()));
}

class DomeClipper extends CustomClipper<Path> {
  @override Path getClip(Size size) {
    Path path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, size.height * 0.22);
    path.quadraticBezierTo(size.width * 0.5, 0, size.width, size.height * 0.22);
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }
  @override bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class HomeScreen extends StatefulWidget {
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late HijriCalendar todayHijri;
  late PrayerTimes prayerTimes;
  List<Map<String, dynamic>> fatihaList = [];
  bool showFatihaList = false;
  List<String> hMonths = ["", "MUHARRAM","SAFAR","RABI-UL-AWWAL","RABI-UL-AAKHAR","JAMADIL AWAL","JAMADIL AAKHAR","RAJJAB","SHABAN","RAMZAN","SHAWWAL","ZIL-QAD","ZIL-HAJJ"];

  @override void initState() {
    super.initState();
    todayHijri = HijriCalendar.now();
    try { todayHijri.hDay = todayHijri.hDay - 1; } catch (_) {}
    final coords = Coordinates(23.0225, 72.5714);
    final params = CalculationMethod.karachi.getParameters();
    params.madhab = Madhab.hanafi;
    prayerTimes = PrayerTimes.today(coords, params);
    loadData();
  }

  Future<void> loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('fatiha_list')) {
      setState(() {
        fatihaList = List<Map<String, dynamic>>.from(json.decode(prefs.getString('fatiha_list')!));
      });
    }
  }

  Future<void> saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('fatiha_list', json.encode(fatihaList));
  }

  int daysRemain(int tDay, int tMonth) {
    int todayTotal = (todayHijri.hMonth - 1) * 30 + todayHijri.hDay;
    int targetTotal = (tMonth - 1) * 30 + tDay;
    int diff = targetTotal - todayTotal;
    if (diff < 0) diff += 360;
    return diff;
  }

  Future<void> addFatihaDialog() async {
    TextEditingController nameCtrl = TextEditingController();
    int selDay = todayHijri.hDay;
    int selMonth = todayHijri.hMonth;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext stContext, StateSetter setD) {
            return AlertDialog(
              title: Text('ADD FATIHA', style: TextStyle(color: Color(0xFF0F4D24), fontWeight: FontWeight.bold, fontSize: 15)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Marhoom ka naam', border: OutlineInputBorder())),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: selDay,
                          decoration: InputDecoration(labelText: 'Day'),
                          items: List.generate(30, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                          onChanged: (v) { setD(() { selDay = v!; }); },
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          value: selMonth,
                          decoration: InputDecoration(labelText: 'Month'),
                          items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(hMonths[i + 1], style: TextStyle(fontSize: 10)))),
                          onChanged: (v) { setD(() { selMonth = v!; }); },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0F4D24)),
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty) return;
                    int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
                    Map<String, dynamic> item = {'id': id, 'name': nameCtrl.text, 'iDay': selDay, 'iMonth': selMonth};
                    int remain = daysRemain(selDay, selMonth);
                    for (int i = 0; i < 3; i++) {
                      int off = [7, 1, 0][i];
                      if (remain >= off) {
                        var when = tz.TZDateTime.now(tz.local).add(Duration(days: remain - off, hours: 8));
                        await flutterLocalNotificationsPlugin.zonedSchedule(
                          id * 10 + i,
                          '${item['name']} ki Fatiha',
                          '${selDay} ${hMonths[selMonth]}',
                          when,
                          const NotificationDetails(android: AndroidNotificationDetails('fatiha_channel', 'Fatiha', importance: Importance.high)),
                          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
                        );
                      }
                    }
                    setState(() { fatihaList.add(item); });
                    await saveData();
                    Navigator.pop(dialogContext);
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

  Future<void> shareFullList() async {
    if (fatihaList.isEmpty) return;
    String text = '*MY FATIHA LIST*\n\n';
    for (var r in fatihaList) {
      int d = daysRemain(r['iDay'], r['iMonth']);
      text += "${r['name']} - ${r['iDay']} ${hMonths[r['iMonth']]} -> $d days\n";
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/fatiha.json');
      await file.writeAsString(json.encode(fatihaList));
      await Share.shareXFiles([XFile(file.path)], text: text);
    } catch (_) { Share.share(text); }
  }

  @override Widget build(BuildContext context) {
    String islamicDateStr = "${todayHijri.hDay.toString().padLeft(2,'0')} - ${todayHijri.hMonth.toString().padLeft(2,'0')} - ${todayHijri.hYear}";
    String engDate = "${DateTime.now().day.toString().padLeft(2,'0')}-${DateTime.now().month.toString().padLeft(2,'0')}-${DateTime.now().year}";

    return Scaffold(
      backgroundColor: Color(0xFFF2F7F2),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              width: double.infinity, height: 560,
              margin: EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Color(0xFF0F4D24), width: 5), borderRadius: BorderRadius.circular(8)),
              child: ClipPath(
                clipper: DomeClipper(),
                child: Container(
                  color: Colors.white,
                  child: Column(children: [
                    SizedBox(height: 50),
                    Text(hMonths[todayHijri.hMonth], style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F4D24))),
                    SizedBox(height: 10),
                    Text(islamicDateStr, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF0F4D24))),
                    SizedBox(height: 8),
                    Text("English Date: $engDate", style: TextStyle(fontSize: 14, color: Colors.grey)),
                    SizedBox(height: 10),
                    Container(height: 1, width: 260, color: Color(0xFF0F4D24)),
                    SizedBox(height: 14),
                    Text("NAMAZ TIME RANGE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F4D24))),
                    SizedBox(height: 18),
                    Text("Fajr  05:25 - 06:40", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0F4D24))),
                    SizedBox(height: 6),
                    Text("Zuhr  12:25 - 16:30", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0F4D24))),
                    SizedBox(height: 6),
                    Text("Asr  16:30 - 18:07", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0F4D24))),
                    SizedBox(height: 6),
                    Text("Maghrib  18:07 - 19:23", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0F4D24))),
                    SizedBox(height: 6),
                    Text("Isha  19:23 - 05:25", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0F4D24))),
                    Spacer(),
                    Padding(
                      padding: EdgeInsets.fromLTRB(12, 0, 12, 14),
                      child: Row(children: [
                        Expanded(child: ElevatedButton(onPressed: addFatihaDialog, style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0F4D24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text("+ Add Fatiha", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
                        SizedBox(width: 10),
                        Expanded(child: ElevatedButton(onPressed: addFatihaDialog, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, side: BorderSide(color: Color(0xFF0F4D24), width: 2)), child: Text("+ Add Urs", style: TextStyle(color: Color(0xFF0F4D24), fontWeight: FontWeight.bold)))),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
        Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Text('MY FATIHA LIST (${fatihaList.length})', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F4D24), fontSize: 12)),
              Switch(value: showFatihaList, activeColor: Color(0xFF0F4D24), onChanged: (v) { setState(() { showFatihaList = v; }); }),
              Text(showFatihaList ? 'ON' : 'OFF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: showFatihaList ? Color(0xFF0F4D24) : Colors.grey)),
            ]),
            IconButton(icon: Icon(Icons.share, size: 20, color: Color(0xFF0F4D24)), onPressed: shareFullList),
          ]),
        ),
        AnimatedContainer(
          duration: Duration(milliseconds: 300),
          height: showFatihaList ? 320 : 0,
          child: showFatihaList ? Container(
            margin: EdgeInsets.fromLTRB(8, 0, 8, 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Color(0xFF0F4D24))),
            child: fatihaList.isEmpty ? Center(child: Text('Add Fatiha dabao', style: TextStyle(fontSize: 11))) : ListView.builder(
             
