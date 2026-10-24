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
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

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
    double w=size.width,h=size.height;
    Path path=Path();
    path.moveTo(w/2,0);
    path.cubicTo(w*0.65,h*0.08,w,h*0.18,w,h*0.30);
    path.lineTo(w, h); path.lineTo(0, h); path.lineTo(0, h*0.30);
    path.cubicTo(0,h*0.18,w*0.35,h*0.08,w/2,0); path.close(); return path;
  }
  @override bool shouldReclip(old)=>false;
}
class FullArchPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size size) {
    double w=size.width,h=size.height;
    Path path=Path();
    path.moveTo(w/2,0);
    path.cubicTo(w*0.65,h*0.08,w,h*0.18,w,h*0.30);
    path.lineTo(w, h); path.lineTo(0, h*0.30);
    path.cubicTo(0,h*0.18,w*0.35,h*0.08,w/2,0); path.close();
    canvas.drawShadow(path, Colors.black26, 10, true);
    canvas.drawPath(path, Paint()..color=Colors.white..style=PaintingStyle.fill);
    canvas.drawPath(path, Paint()..color=Color(0xFF0F4D24)..style=PaintingStyle.stroke..strokeWidth=12);
  }
  @override bool shouldRepaint(old)=>false;
}

class HomeScreen extends StatefulWidget { @override _HomeScreenState createState()=>_HomeScreenState(); }

class _HomeScreenState extends State<HomeScreen> {
  late HijriCalendar todayHijri;
  late PrayerTimes prayerTimes;
  List<Map<String,dynamic>> fatihaList=[];
  String adminPin="78692";

  @override void initState(){
    super.initState();
    todayHijri=HijriCalendar.now(); todayHijri.hDay=todayHijri.hDay-1;
    final coords=Coordinates(23.0225,72.5714);
    final params=CalculationMethod.karachi.getParameters(); params.madhab=Madhab.hanafi;
    prayerTimes=PrayerTimes.today(coords, params);
    loadData();
  }

  Future<void> loadData() async {
    SharedPreferences prefs=await SharedPreferences.getInstance();
    if(prefs.containsKey('fatiha_list')){
      setState(()=>fatihaList=List<Map<String,dynamic>>.from(json.decode(prefs.getString('fatiha_list')!)));
    }
    // GujChand Auto - 27,28,29 को 7PM बाद
    if(prefs.containsKey('gujchand_auto')){
      try{
        var s=json.decode(prefs.getString('gujchand_auto')!);
        if(DateTime.now().difference(DateTime.parse(s['time'])).inHours<12){
          setState((){ todayHijri.hDay=s['day']; todayHijri.hMonth=s['month']; todayHijri.hYear=s['year']; });
        }
      }catch(_){}
    }
  }
  Future<void> saveData() async {
    SharedPreferences prefs=await SharedPreferences.getInstance();
    prefs.setString('fatiha_list', json.encode(fatihaList));
  }

  // Countdown Logic - आज से Target तक
  int daysRemain(int tDay, int tMonth){
    int todayTotal=(todayHijri.hMonth-1)*30 + todayHijri.hDay;
    int targetTotal=(tMonth-1)*30 + tDay;
    int diff=targetTotal - todayTotal;
    if(diff<0) diff+=360; // अगला साल
    return diff;
  }

  Color getColor(int days){
    if(days<=7) return Color(0xFFD32F2F); // Red - 0-7
    if(days<=60) return Color(0xFFFFC107); // Yellow - 7-60
    return Colors.black87; // Normal
  }
  Color getBg(int days){
    if(days<=7) return Color(0xFFFFEBEE);
    if(days<=60) return Color(0xFFFFF8E1);
    return Colors.white;
  }

  Future<void> addFatihaDialog() async {
    TextEditingController nameCtrl=TextEditingController();
    int iDay=todayHijri.hDay, iMonth=todayHijri.hMonth, iYear=todayHijri.hYear;
    DateTime eDate=DateTime.now();
    TextEditingController eDateCtrl=TextEditingController(text: "${eDate.day}-${eDate.month}-${eDate.year}");

    await showDialog(context: context, builder: (c)=>AlertDialog(
      title: Text('ADD FATIHA', style: TextStyle(color: Color(0xFF0F4D24), fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(child: Column(children: [
        TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'मरहूम का नाम (Unlimited)', border: OutlineInputBorder())),
        SizedBox(height: 12),
        Text('Islamic Date', style: TextStyle(fontWeight: FontWeight.bold)),
        Row(children: [
          Expanded(child: TextField(decoration: InputDecoration(labelText: 'Day'), keyboardType: TextInputType.number, controller: TextEditingController(text: iDay.toString()), onChanged: (v)=>iDay=int.tryParse(v)??iDay)),
          SizedBox(width: 8),
          Expanded(child: TextField(decoration: InputDecoration(labelText: 'Month'), keyboardType: TextInputType.number, controller: TextEditingController(text: iMonth.toString()), onChanged: (v)=>iMonth=int.tryParse(v)??iMonth)),
          SizedBox(width: 8),
          Expanded(child: TextField(decoration: InputDecoration(labelText: 'Year'), keyboardType: TextInputType.number, controller: TextEditingController(text: iYear.toString()), onChanged: (v)=>iYear=int.tryParse(v)??iYear)),
        ]),
        SizedBox(height: 12),
        Text('English Date', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(controller: eDateCtrl, readOnly: true, decoration: InputDecoration(labelText: 'English Date', suffixIcon: Icon(Icons.calendar_today), border: OutlineInputBorder()),
          onTap: () async {
            DateTime? picked=await showDatePicker(context: context, initialDate: eDate, firstDate: DateTime(1950), lastDate: DateTime(2030));
            if(picked!=null){ eDate=picked; eDateCtrl.text="${picked.day}-${picked.month}-${picked.year}"; }
          },
        ),
      ])),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(c), child: Text('Cancel')),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0F4D24)), onPressed: () async {
          if(nameCtrl.text.isEmpty) return;
          int id=DateTime.now().millisecondsSinceEpoch.remainder(100000);
          Map<String,dynamic> item={
            'id':id, 'name':nameCtrl.text, 'iDay':iDay, 'iMonth':iMonth, 'iYear':iYear,
            'eDate':eDateCtrl.text, 'created':DateTime.now().toIso8601String()
          };
          // 3 Notification: 7 दिन, 1 दिन, उसी दिन
          int remain=daysRemain(iDay, iMonth);
          await scheduleNotifs(id, item, remain);
          setState(()=>fatihaList.add(item));
          await saveData();
          Navigator.pop(c);
        }, child: Text('Save', style: TextStyle(color: Colors.white))),
      ],
    ));
  }

  Future<void> scheduleNotifs(int baseId, Map<String,dynamic> item, int remain) async {
    try{
      List<int> offsets=[7,1,0]; // 7 दिन पहले, 1 दिन पहले, उसी दिन
      for(int i=0;i<offsets.length;i++){
        int daysBefore=offsets[i];
        if(remain>=daysBefore){
          int scheduleAfter=remain-daysBefore;
          var when=tz.TZDateTime.now(tz.local).add(Duration(days: scheduleAfter, hours: 8)); // सुबह 8 बजे
          await flutterLocalNotificationsPlugin.zonedSchedule(
            baseId*10+i,
            '${item['name']} की Fatiha ${daysBefore==0 ? 'आज' : '$daysBefore दिन में'}',
            '${item['name']} - ${item['iDay']} Jamadil Awal - ${item['eDate']}',
            when,
            const NotificationDetails(android: AndroidNotificationDetails('fatiha_channel','Fatiha', importance: Importance.high)),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
        }
      }
    }catch(_){}
  }

  Future<void> shareFullList() async {
    if(fatihaList.isEmpty) return;
    String text="*MY FATIHA LIST*\n\n";
    for(var r in fatihaList){
      int d=daysRemain(r['iDay'], r['iMonth']);
      text+="${r['name']} - ${r['iDay'].toString().padLeft(2,'0')} Jamadil Awal (${r['eDate']}) -> $d days remain\n";
    }
    text+="\nFatiha-Urs-Reminder-App";
    // File Backup
    try{
      final dir=await getApplicationDocumentsDirectory();
      final file=File('${dir.path}/fatiha_list.json');
      await file.writeAsString(json.encode(fatihaList));
      await Share.shareXFiles([XFile(file.path)], text: text);
    }catch(_){
      Share.share(text);
    }
  }

  @override Widget build(BuildContext context){
    double sw=MediaQuery.of(context).size.width, sh=MediaQuery.of(context).size.height;
    List<String> hMonths=["", "MUHARRAM","SAFAR","RABI-AWWAL","RABI-THANI","JAMADIL AWAL","JAMADIL THANI","RAJAB","SHABAN","RAMZAN","SHAWWAL","ZIL-QAD","ZIL-HAJJ"];
    String islamicDateStr="${todayHijri.hDay.toString().padLeft(2,'0')} - ${todayHijri.hMonth.toString().padLeft(2,'0')} - ${todayHijri.hYear}";

    return Scaffold(
      backgroundColor: Color(0xFFF2F7F2),
      body: SafeArea(child: Column(children: [
        // TOP DOME
        SizedBox(height: sh*0.55, child: Stack(children: [
          CustomPaint(painter: FullArchPainter(), size: Size(sw, sh*0.55)),
          ClipPath(
            clipper: FullArchClipper(),
            child: Container(width: sw, height: sh*0.55, color: Colors.white, child: Column(children: [
              SizedBox(height: sh*0.08),
              Text(hMonths[todayHijri.hMonth], style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F4D24))),
              SizedBox(height: 8),
              Text(islamicDateStr, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F4D24))),
              SizedBox(height: 8),
              Text("English: ${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}", style: TextStyle(fontSize: 12, color: Colors.grey)),
              Divider(indent: 50, endIndent: 50, color: Color(0xFF0F4D24)),
              Text("NAMAZ TIME", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F4D24))),
              SizedBox(height: 6),
              Text("Fajr 05:25 - 06:40  |  Zuhr 12:25 - 16:30", style: TextStyle(fontSize: 11, color: Color(0xFF0F4D24))),
              Spacer(),
              Padding(padding: EdgeInsets.fromLTRB(12,0,12,12), child: Row(children: [
                Expanded(child: ElevatedButton(onPressed: addFatihaDialog, style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0F4D24)), child: Text("+ Add Fatiha", style: TextStyle(color: Colors.white, fontSize: 12)))),
                SizedBox(width: 8),
                Expanded(child: ElevatedButton(onPressed: addFatihaDialog, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, side: BorderSide(color: Color(0xFF0F4D24))), child: Text("+ Add Urs", style: TextStyle(color: Color(0xFF0F4D24), fontSize: 12)))),
              ])),
            ])),
          ),
        ])),
        // MY FATIHA LIST - NEW TIMER
        Padding(padding: EdgeInsets.all(8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('MY FATIHA LIST - NEW TIMER (${fatihaList.length})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F4D24))),
          Row(children: [
            IconButton(icon: Icon(Icons.backup, color: Color(0xFF0F4D24)), onPressed: shareFullList, tooltip: 'Backup & Share File'),
            IconButton(icon: Icon(Icons.share, color: Color(0xFF0F4D24)), onPressed: shareFullList),
          ])
        ])),
        Expanded(child: Container(
          margin: EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Color(0xFF0F4D24))),
          child: fatihaList.isEmpty ? Center(child: Text('कोई नाम नहीं - Add Fatiha दबाओ')) : ListView.builder(
            itemCount: fatihaList.length,
            itemBuilder: (c,i){
              var r=fatihaList[i];
              int days=daysRemain(r['iDay'], r['iMonth']);
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: getBg(days), borderRadius: BorderRadius.circular(8), border: Border.all(color: getColor(days).withOpacity(0.3))),
                child: ListTile(
                  title: Text("${r['name']} - ${r['iDay'].toString().padLeft(2,'0')} Jamadil Awal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: getColor(days))),
                  subtitle: Text("Eng: ${r['eDate']} -> $days days remain", style: TextStyle(fontSize: 12)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text("$days दिन", style: TextStyle(fontWeight: FontWeight.bold, color: getColor(days))),
                    IconButton(icon: Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () async { setState(()=>fatihaList.removeAt(i)); await saveData(); }),
                  ]),
                ),
              );
            },
          ),
        )),
      ])),
    );
  }
}
