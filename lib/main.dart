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
    path.lineTo(w, h); path.lineTo(0, h*0.30);
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
    path.lineTo(w, h); path.lineTo(0, h); path.lineTo(0, h*0.30);
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
  List<String> hMonths=["", "MUHARRAM","SAFAR","RABI-UL-AWWAL","RABI-UL-AAKHAR","JAMADIL AWAL","JAMADIL AAKHAR","RAJJAB","SHABAN","RAMZAN","SHAWWAL","ZIL-QAD","ZIL-HAJJ"];

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
  }
  Future<void> saveData() async {
    SharedPreferences prefs=await SharedPreferences.getInstance();
    prefs.setString('fatiha_list', json.encode(fatihaList));
  }

  int daysRemain(int tDay, int tMonth){
    int todayTotal=(todayHijri.hMonth-1)*30 + todayHijri.hDay;
    int targetTotal=(tMonth-1)*30 + tDay;
    int diff=targetTotal - todayTotal;
    if(diff<0) diff+=360;
    return diff;
  }
  Color getColor(int days){
    if(days<=7) return Color(0xFFD32F2F);
    if(days<=60) return Color(0xFFE65100);
    return Colors.black87;
  }
  Color getBg(int days){
    if(days<=7) return Color(0xFFFFEBEE);
    if(days<=60) return Color(0xFFFFF8E1);
    return Colors.white;
  }

  Future<void> addFatihaDialog() async {
    TextEditingController nameCtrl=TextEditingController();
    int selDay=todayHijri.hDay, selMonth=todayHijri.hMonth;

    await showDialog(context: context, builder: (c)=>StatefulBuilder(builder: (c,setD)=>AlertDialog(
      title: Text('ADD FATIHA', style: TextStyle(color: Color(0xFF0F4D24), fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'मरहूम का नाम', border: OutlineInputBorder())),
        SizedBox(height: 16),
        Row(children: [
          Expanded(child: DropdownButtonFormField<int>(value: selDay, decoration: InputDecoration(labelText: 'Day (Islamic)'), items: List.generate(30, (i)=>DropdownMenuItem(value: i+1, child: Text("${i+1}"))), onChanged: (v)=>setD(()=>selDay=v!))),
          SizedBox(width: 8),
          Expanded(flex: 2, child: DropdownButtonFormField<int>(value: selMonth, decoration: InputDecoration(labelText: 'Month (Islamic)'), items: List.generate(12, (i)=>DropdownMenuItem(value: i+1, child: Text(hMonths[i+1], style: TextStyle(fontSize: 11)))), onChanged: (v)=>setD(()=>selMonth=v!))),
        ]),
        SizedBox(height: 12),
        Container(padding: EdgeInsets.all(8), color: Color(0xFFE8F5E9), child: Text('हर साल ${selDay.toString().padLeft(2,'0')} - ${selMonth.toString().padLeft(2,'0')} को याद दिलाएगा\nसिर्फ Islamic Date पर', style: TextStyle(fontSize: 11, color: Color(0xFF0F4D24)), textAlign: TextAlign.center)),
      ]),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(c), child: Text('Cancel')),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0F4D24)), onPressed: () async {
          if(nameCtrl.text.isEmpty) return;
          int id=DateTime.now().millisecondsSinceEpoch.remainder(100000);
          Map<String,dynamic> item={'id':id, 'name':nameCtrl.text, 'iDay':selDay, 'iMonth':selMonth, 'created':DateTime.now().toIso8601String()};
          int remain=daysRemain(selDay, selMonth);
          for(int i=0;i<3;i++){
            int off=[7,1,0][i];
            if(remain>=off){
              var when=tz.TZDateTime.now(tz.local).add(Duration(days: remain-off, hours: 8));
              await flutterLocalNotificationsPlugin.zonedSchedule(id*10+i, '${item['name']} की Fatiha ${off==0 ? 'आज' : '$off दिन में'}', '${selDay} ${hMonths[selMonth]} - हर साल इसी तारीख पर', when, const NotificationDetails(android: AndroidNotificationDetails('fatiha_channel','Fatiha', importance: Importance.high)), androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
            }
          }
          setState(()=>fatihaList.add(item));
          await saveData();
          Navigator.pop(c);
        }, child: Text('Save', style: TextStyle(color: Colors.white))),
      ],
    )));
  }

  Future<void> shareFullList() async {
    if(fatihaList.isEmpty) return;
    String text="*MY FATIHA LIST - Islamic Date Only*\n\n";
    for(var r in fatihaList){
      int d=daysRemain(r['iDay'], r['iMonth']);
      text+="${r['name']} - ${r['iDay'].toString().padLeft(2,'0')} ${hMonths[r['iMonth']]} -> $d days remain\n";
    }
    try{
      final dir=await getApplicationDocumentsDirectory();
      final file=File('${dir.path}/fatiha_islamic.json');
      await file.writeAsString(json.encode(fatihaList));
      await Share.shareXFiles([XFile(file.path)], text: text);
    }catch(_){ Share.share(text); }
  }

  @override Widget build(BuildContext context){
    double sw=MediaQuery.of(context).size.width, sh=MediaQuery.of(context).size.height;
    String islamicDateStr="${todayHijri.hDay.toString().padLeft(2,'0')} - ${todayHijri.hMonth.toString().padLeft(2,'0')} - ${todayHijri.hYear}";
    String engDate="${DateTime.now().day.toString().padLeft(2,'0')} - ${DateTime.now().month.toString().padLeft(2,'0')} - ${DateTime.now().year}";

    return Scaffold(
      backgroundColor: Color(0xFFF2F7F2),
      body: SafeArea(child: Column(children: [
        SizedBox(height: sh*0.55, child: Stack(children: [
          CustomPaint(painter: FullArchPainter(), size: Size(sw, sh*0.55)),
          ClipPath(
            clipper: FullArchClipper(),
            child: Container(width: sw, height: sh*0.55, color: Colors.white, child: Column(children: [
              SizedBox(height: sh*0.08),
              Text(hMonths[todayHijri.hMonth], style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F4D24))),
              SizedBox(height: 8),
              Text(islamicDateStr, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F4D24))),
              SizedBox(height: 6),
              Text("English Date: $engDate", style: TextStyle(fontSize: 12, color: Colors.grey)), // सिर्फ दिखाने के लिए
              Divider(indent: 50, endIndent: 50, color: Color(0xFF0F4D24)),
              Text("NAMAZ TIME", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F4D24))),
              Spacer(),
              Padding(padding: EdgeInsets.fromLTRB(12,0,12,12), child: Row(children: [
                Expanded(child: ElevatedButton(onPressed: addFatihaDialog, style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0F4D24)), child: Text("+ Add Fatiha", style: TextStyle(color: Colors.white, fontSize: 12)))),
                SizedBox(width: 8),
                Expanded(child: ElevatedButton(onPressed: addFatihaDialog, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, side: BorderSide(color: Color(0xFF0F4D24))), child: Text("+ Add Urs", style: TextStyle(color: Color(0xFF0F4D24), fontSize: 12)))),
              ])),
            ])),
          ),
        ])),
        Padding(padding: EdgeInsets.all(8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('MY FATIHA LIST (${fatihaList.length})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F4D24))),
          IconButton(icon: Icon(Icons.share, color: Color(0xFF0F4D24)), onPressed: shareFullList),
        ])),
        Expanded(child: Container(
          margin: EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Color(0xFF0F4D24))),
          child: fatihaList.isEmpty ? Center(child: Text('Add Fatiha दबाओ - सिर्फ Islamic Day+Month')) : ListView.builder(
            itemCount: fatihaList.length,
            itemBuilder: (c,i){
              var r=fatihaList[i];
              int days=daysRemain(r['iDay'], r['iMonth']);
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: getBg(days), borderRadius: BorderRadius.circular(8), border: Border.all(color: getColor(days).withOpacity(0.4))),
                child: ListTile(
                  title: Text("${r['name']} - ${r['iDay'].toString().padLeft(2,'0')} ${hMonths[r['iMonth']]}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: getColor(days))),
                  subtitle: Text("-> $days days remain", style: TextStyle(fontSize: 11)),
                  trailing: IconButton(icon: Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () async { setState(()=>fatihaList.removeAt(i)); await saveData(); }),
                ),
              );
            },
          ),
        )),
      ])),
    );
  }
}
