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
  const AndroidInitializationSettings initAndroid = AndroidInitializationSettings('@mipmap/launcher_icon');
  const InitializationSettings initSettings = InitializationSettings(android: initAndroid);
  await flutterLocalNotificationsPlugin.initialize(initSettings);
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: HomeScreen()));
}

// आपका वही Dome Design - Change नहीं
class FullArchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
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
    path.cubicTo(0, h * 0.18, w * 0.35, h * 0.08, w / 2, 0); path.close();
    canvas.drawShadow(path, Colors.black26, 10, true);
    Paint fill = Paint()..color = Colors.white..style = PaintingStyle.fill;
    Paint border = Paint()..color = Color(0xFF0F4D24)..style = PaintingStyle.stroke..strokeWidth = 12..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, fill); canvas.drawPath(path, border);
  }
  @override bool shouldRepaint(old) => false;
}

class HomeScreen extends StatefulWidget { @override _HomeScreenState createState() => _HomeScreenState(); }

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> reminders = [];
  late HijriCalendar todayHijri;
  late PrayerTimes prayerTimes;
  String adminPin = "78692"; // आपका PIN - Change कर सकते हो

  @override
  void initState() {
    super.initState();
    todayHijri = getTodayHijriWithSunset();
    calcPrayerTimes();
    loadReminders();
    requestPerm();
  }

  Future<void> requestPerm() async {
    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  // 1. Islamic Date - Sunset + 15 min Logic - SAME LOOK
  HijriCalendar getTodayHijriWithSunset() {
    HijriCalendar hijri = HijriCalendar.now();
    final coords = Coordinates(23.0225, 72.5714);
    final params = CalculationMethod.karachi.getParameters();
    params.madhab = Madhab.hanafi;
    final pt = PrayerTimes.today(coords, params);
    DateTime sunsetChange = pt.maghrib.add(Duration(minutes: 15));
    if (DateTime.now().isAfter(sunsetChange)) {
      hijri.hDay += 1;
      if (hijri.hDay > 30) { hijri.hDay = 1; hijri.hMonth += 1; if (hijri.hMonth > 12) { hijri.hMonth = 1; hijri.hYear += 1; } }
    }
    // Admin Override Check
    SharedPreferences.getInstance().then((prefs) {
      if (prefs.containsKey('admin_hijri')) {
        var admin = json.decode(prefs.getString('admin_hijri')!);
        setState(() { hijri.hDay = admin['day']; hijri.hMonth = admin['month']; hijri.hYear = admin['year']; });
      }
    });
    return hijri;
  }

  void calcPrayerTimes() {
    final coords = Coordinates(23.0225, 72.5714);
    final params = CalculationMethod.karachi.getParameters();
    params.madhab = Madhab.hanafi;
    prayerTimes = PrayerTimes.today(coords, params);
  }

  Future<void> loadReminders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('reminders');
    if (data != null) setState(() => reminders = List<Map<String, dynamic>>.from(json.decode(data)));
  }
  Future<void> saveReminders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('reminders', json.encode(reminders));
  }

  String getDaysLeft(Map<String, dynamic> item) {
    try {
      int hDay = item['hDay']; int hMonth = item['hMonth'];
      HijriCalendar now = getTodayHijriWithSunset();
      HijriCalendar target = HijriCalendar(); target.hYear = now.hYear; target.hMonth = hMonth; target.hDay = hDay;
      DateTime gTarget = target.hijriToGregorian(target.hYear, target.hMonth, target.hDay);
      DateTime gNow = DateTime.now();
      if (gTarget.isBefore(gNow)) { target.hYear = now.hYear + 1; gTarget = target.hijriToGregorian(target.hYear, target.hMonth, target.hDay); }
      int diff = gTarget.difference(gNow).inDays;
      if (diff == 0) return "आज है!"; if (diff == 1) return "कल है"; return "$diff दिन बाकी";
    } catch (e) { return ""; }
  }

  // 2. Add Dialog - Islamic First, Past Allow
  Future<void> addDialog(String type) async {
    TextEditingController nameCtrl = TextEditingController();
    int selHDay = todayHijri.hDay; int selHMonth = todayHijri.hMonth; int selHYear = todayHijri.hYear;
    await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (context, setS) {
      List<String> hMonths = ["Muharram","Safar","Rabi-al-Awwal","Rabi-al-Thani","Jamadil Awal","Jamadil Thani","Rajab","Shaban","Ramzan","Shawwal","Zil-Qad","Zil-Hajj"];
      return AlertDialog(
        title: Text('$type जोड़ें', style: TextStyle(color: Color(0xFF0F4D24), fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'नाम', border: OutlineInputBorder())),
          SizedBox(height: 12),
          Text("इस्लामी तारीख (वफात) - चाँद के हिसाब से", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F4D24))),
          SizedBox(height: 8),
          Row(children: [
            Expanded(child: DropdownButtonFormField<int>(value: selHDay, items: List.generate(30, (i) => DropdownMenuItem(value: i+1, child: Text("${i+1}"))), onChanged: (v)=>setS(()=>selHDay=v!), decoration: InputDecoration(labelText: 'दिन'))),
            SizedBox(width: 6),
            Expanded(flex:2, child: DropdownButtonFormField<int>(value: selHMonth, items: List.generate(12, (i) => DropdownMenuItem(value: i+1, child: Text(hMonths[i], overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12)))) , onChanged: (v)=>setS(()=>selHMonth=v!), decoration: InputDecoration(labelText: 'महीना'))),
          ]),
          SizedBox(height: 8),
          DropdownButtonFormField<int>(value: selHYear, items: List.generate(80, (i) { int y = todayHijri.hYear - i; return DropdownMenuItem(value: y, child: Text("$y Hijri")); }), onChanged: (v)=>setS(()=>selHYear=v!), decoration: InputDecoration(labelText: 'साल (पुरानी भी)')),
        ])),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(c), child: Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0F4D24)), onPressed: () async {
            if(nameCtrl.text.isEmpty) return;
            HijriCalendar next = HijriCalendar(); next.hDay=selHDay; next.hMonth=selHMonth; next.hYear=todayHijri.hYear;
            DateTime nextG = next.hijriToGregorian(next.hYear, next.hMonth, next.hDay);
            if(nextG.isBefore(DateTime.now())) { next.hYear++; nextG = next.hijriToGregorian(next.hYear, next.hMonth, next.hDay); }
            int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
            Map<String,dynamic> newItem = {'id':id,'name':'$type: ${nameCtrl.text}','hDay':selHDay,'hMonth':selHMonth,'hYear':selHYear,'nextDate':nextG.toIso8601String()};
            setState(()=>reminders.add(newItem));
            await saveReminders();
            await flutterLocalNotificationsPlugin.zonedSchedule(id, '$type Reminder', '${nameCtrl.text} की $type आज है', tz.TZDateTime.from(nextG, tz.local), const NotificationDetails(android: AndroidNotificationDetails('fatiha_urs','Fatiha Urs', importance: Importance.max, priority: Priority.high)), androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
            Navigator.pop(c);
          }, child: Text('Save', style: TextStyle(color: Colors.white))),
        ],
      );
    }));
  }

  void deleteItem(int index) async {
    await flutterLocalNotificationsPlugin.cancel(reminders[index]['id']);
    setState(()=>reminders.removeAt(index)); await saveReminders();
  }

  // Share पूरी लिस्ट - एक बटन
  Future<void> shareFullList() async {
    if(reminders.isEmpty) return;
    String jsonStr = json.encode(reminders);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/fatiha_list.json');
    await file.writeAsString(jsonStr);
    await Share.shareXFiles([XFile(file.path)], text: 'मेरी Fatiha/Urs लिस्ट - Fatiha Urs App से शेयर की गई');
  }

  // Import
  Future<void> importList(String jsonStr) async {
    try { List list = json.decode(jsonStr); setState(()=>reminders.addAll(List<Map<String,dynamic>>.from(list))); await saveReminders(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${list.length} नाम Import हो गए!'))); } catch(e){}
  }

  // Admin Panel - Long Press + PIN
  void openAdminCheck() {
    TextEditingController pinCtrl = TextEditingController();
    showDialog(context: context, builder: (c)=>AlertDialog(
      title: Text('Admin PIN डालो'),
      content: TextField(controller: pinCtrl, obscureText: true, decoration: InputDecoration(hintText: 'PIN')),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(c), child: Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if(pinCtrl.text == adminPin) {
            Navigator.pop(c); openAdminPanel();
          } else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('गलत PIN'))); }
        }, child: Text('OK'))
      ],
    ));
  }
  void openAdminPanel() {
    int d = todayHijri.hDay, m = todayHijri.hMonth, y = todayHijri.hYear;
    showDialog(context: context, builder: (c)=>StatefulBuilder(builder: (ctx,setS)=>AlertDialog(
      title: Text('Admin - Islamic Date Change'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(decoration: InputDecoration(labelText: 'Day'), keyboardType: TextInputType.number, controller: TextEditingController(text: d.toString()), onChanged: (v)=>d=int.tryParse(v)??d),
        TextField(decoration: InputDecoration(labelText: 'Month'), keyboardType: TextInputType.number, controller: TextEditingController(text: m.toString()), onChanged: (v)=>m=int.tryParse(v)??m),
        TextField(decoration: InputDecoration(labelText: 'Year'), keyboardType: TextInputType.number, controller: TextEditingController(text: y.toString()), onChanged: (v)=>y=int.tryParse(v)??y),
      ]),
      actions: [
        ElevatedButton(onPressed: () async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setString('admin_hijri', json.encode({'day':d,'month':m,'year':y}));
          setState(()=>todayHijri = getTodayHijriWithSunset());
          Navigator.pop(c);
        }, child: Text('Save for All Users'))
      ],
    )));
  }

  Widget rowItem(String n, String t) {
    return Padding(padding: EdgeInsets.symmetric(vertical: 5), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 80, child: Text(n, textAlign: TextAlign.right, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F4D24)))),
      SizedBox(width: 12), Text(t, style: TextStyle(fontSize: 15, color: Color(0xFF0F4D24))),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    double sw = MediaQuery.of(context).size.width; double sh = MediaQuery.of(context).size.height;
    List<String> hMonthsEng = ["", "MUHARRAM","SAFAR","RABI-AL-AWWAL","RABI-AL-THANI","JAMADIL AWAL","JAMADIL THANI","RAJAB","SHABAN","RAMZAN","SHAWWAL","ZIL-QAD","ZIL-HAJJ"];
    String islamicDateStr = "${todayHijri.hDay.toString().padLeft(2,'0')} - ${todayHijri.hMonth.toString().padLeft(2,'0')} - ${todayHijri.hYear}";
    String islamicMonthStr = hMonthsEng[todayHijri.hMonth];
    String engDate = "${DateTime.now().day.toString().padLeft(2,'0')}-${DateTime.now().month.toString().padLeft(2,'0')}-${DateTime.now().year}";
    // Namaz Range from adhan
    String fajrRange = "${prayerTimes.fajr.hour.toString().padLeft(2,'0')}:${prayerTimes.fajr.minute.toString().padLeft(2,'0')} - ${prayerTimes.sunrise.hour.toString().padLeft(2,'0')}:${prayerTimes.sunrise.minute.toString().padLeft(2,'0')}";
    String zuhrRange = "${prayerTimes.dhuhr.hour.toString().padLeft(2,'0')}:${prayerTimes.dhuhr.minute.toString().padLeft(2,'0')} - ${prayerTimes.asr.hour.toString().padLeft(2,'0')}:${prayerTimes.asr.minute.toString().padLeft(2,'0')}";
    String asrRange = "${prayerTimes.asr.hour.toString().padLeft(2,'0')}:${prayerTimes.asr.minute.toString().padLeft(2,'0')} - ${prayerTimes.maghrib.hour.toString().padLeft(2,'0')}:${prayerTimes.maghrib.minute.toString().padLeft(2,'0')}";
    String maghribRange = "${prayerTimes.maghrib.hour.toString().padLeft(2,'0')}:${prayerTimes.maghrib.minute.toString().padLeft(2,'0')} - ${prayerTimes.isha.hour.toString().padLeft(2,'0')}:${prayerTimes.isha.minute.toString().padLeft(2,'0')}";
    String ishaRange = "${prayerTimes.isha.hour.toString().padLeft(2,'0')}:${prayerTimes.isha.minute.toString().padLeft(2,'0')} - ${prayerTimes.fajr.hour.toString().padLeft(2,'0')}:${prayerTimes.fajr.minute.toString().padLeft(2,'0')}";

    return Scaffold(
      backgroundColor: Color(0xFFF2F7F2),
      body: SafeArea(child: Padding(padding: EdgeInsets.all(8), child: Column(children: [
        Expanded(flex: 5, child: CustomPaint(
          painter: FullArchPainter(),
          child: ClipPath(
            clipper: FullArchClipper(),
            child: Container(width: sw, height: sh*0.75, child: Column(children: [
              SizedBox(height: sh*0.09),
              Text(islamicMonthStr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F4D24))),
              SizedBox(height: 10),
              Text(islamicDateStr, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF0F4D24))),
              SizedBox(height: 16),
              Text("English Date: $engDate", style: TextStyle(fontSize: 12, color: Colors.grey)),
              SizedBox(height: 8),
              Divider(indent: 50, endIndent: 50, thickness: 1, color: Color(0xFF0F4D24)),
              SizedBox(height: 8),
              GestureDetector(onLongPress: openAdminCheck, child: Text("NAMAZ TIME RANGE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F4D24)))),
              SizedBox(height: 12),
              rowItem("Fajr", fajrRange),
              rowItem("Zuhr", zuhrRange),
              rowItem("Asr", asrRange),
              rowItem("Maghrib", maghribRange),
              rowItem("Isha", ishaRange),
              Spacer(),
              Padding(padding: EdgeInsets.fromLTRB(12,0,12,18), child: Row(children: [
                Expanded(child: SizedBox(height: 46, child: ElevatedButton(onPressed: ()=>addDialog('Fatiha'), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0F4D24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text("+ Add Fatiha", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))))),
                SizedBox(width: 8),
                Expanded(child: SizedBox(height: 46, child: ElevatedButton(onPressed: ()=>addDialog('Urs'), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, side: BorderSide(color: Color(0xFF0F4D24), width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text("+ Add Urs", style: TextStyle(color: Color(0xFF0F4D24), fontWeight: FontWeight.bold, fontSize: 13))))),
              ])),
            ])),
          ),
        )),
        if(reminders.isNotEmpty) Container(margin: EdgeInsets.only(top: 6), padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Color(0xFF0F4D24))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("List: ${reminders.length} नाम", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          Row(children: [
            IconButton(icon: Icon(Icons.upload_file, size: 18), onPressed: () async {
              // Import logic - user will paste json
              TextEditingController c = TextEditingController();
              showDialog(context: context, builder: (ctx)=>AlertDialog(title: Text('Import JSON Paste करो'), content: TextField(controller: c, maxLines: 5), actions: [ElevatedButton(onPressed: (){ importList(c.text); Navigator.pop(ctx); }, child: Text('Import'))]));
            }),
            ElevatedButton.icon(onPressed: shareFullList, icon: Icon(Icons.share, size: 14), label: Text('Share All', style: TextStyle(fontSize: 11)), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0F4D24), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4))),
          ])
        ])),
        if(reminders.isNotEmpty) Expanded(flex: 2, child: Container(margin: EdgeInsets.only(top: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Color(0xFF0F4D24), width: 1)), child: ListView.builder(itemCount: reminders.length, itemBuilder: (ctx,i){
          return ListTile(
            dense: true,
            leading: Icon(Icons.timer, color: Color(0xFF0F4D24), size: 18),
            title: Text(reminders[i]['name'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            subtitle: Text("Hijri: ${reminders[i]['hDay']}/${reminders[i]['hMonth']} - ${getDaysLeft(reminders[i])}", style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
            trailing: IconButton(icon: Icon(Icons.delete, color: Colors.red, size: 18), onPressed: ()=>deleteItem(i)),
          );
        }))),
      ]))),
    );
  }
}
