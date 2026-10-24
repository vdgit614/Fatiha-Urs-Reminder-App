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

// Dome Shape - सुबह वाला हूबहू
class DomeClipper extends CustomClipper<Path> {
  @override Path getClip(Size size) {
    Path path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, size.height * 0.25);
    path.quadraticBezierTo(size.width * 0.5, -10, size.width, size.height * 0.25);
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }
  @override bool shouldReclip(old) => false;
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
  Future<void> loadData() async { SharedPreferences prefs=await SharedPreferences.getInstance(); if(prefs.containsKey('fatiha_list')){ setState(()=>fatihaList=List<Map<String,dynamic>>.from(json.decode(prefs.getString('fatiha_list')!))); } }
  Future<void> saveData() async { SharedPreferences prefs=await SharedPreferences.getInstance(); prefs.setString('fatiha_list', json.encode(fatihaList)); }
  int daysRemain(int tDay, int tMonth){ int todayTotal=(todayHijri.hMonth-1)*30 + todayHijri.hDay; int targetTotal=(tMonth-1)*30 + tDay; int diff=targetTotal - todayTotal; if(diff<0) diff+=360; return diff; }
  Color getColor(int days){ if(days<=7) return Color(0xFFD32F2F); if(days<=60) return Color(0xFFE65100); return Color(0xFF0F4D24); }

  Future<void> addFatihaDialog() async {
    TextEditingController nameCtrl=TextEditingController();
    int selDay=todayHijri.hDay, selMonth=todayHijri.hMonth;
    await showDialog(context: context, builder: (c)=>StatefulBuilder(builder: (c,setD)=>AlertDialog(
      title: Text('ADD FATIHA - Islamic Only', style: TextStyle(color: Color(0xFF0F4D24), fontWeight: FontWeight.bold, fontSize: 14)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'मरहूम का नाम', border: OutlineInputBorder())),
        SizedBox(height: 12),
        Row(children: [
          Expanded(child: DropdownButtonFormField<int>(value: selDay, decoration: InputDecoration(labelText: 'Day'), items: List.generate(30, (i)=>DropdownMenuItem(value: i+1, child: Text("${i+1}"))), onChanged: (v)=>setD(()=>selDay=v!))),
          SizedBox(width: 8),
          Expanded(flex: 2, child: DropdownButtonFormField<int>(value: selMonth, decoration: InputDecoration(labelText: 'Month'), items: List.generate(12, (i)=>DropdownMenuItem(value: i+1, child: Text(hMonths[i+1], style: TextStyle(fontSize: 10)))), onChanged: (v)=>setD(()=>selMonth=v!))),
        ]),
        SizedBox(height: 8),
        Text('हर साल ${selDay} ${hMonths[selMonth]} को याद दिलाएगा', style: TextStyle(fontSize: 11, color: Color(0xFF0F4D24))),
      ]),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(c), child: Text('Cancel')),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0F4D24)), onPressed: () async {
          if(nameCtrl.text.isEmpty) return;
          int id=DateTime.now().millisecondsSinceEpoch.remainder(100000);
          Map<String,dynamic> item={'id':id, 'name':nameCtrl.text, 'iDay':selDay, 'iMonth':selMonth};
          int remain=daysRemain(selDay, selMonth);
          for(int i=0;i<3;i++){ int off=[7,1,0][i]; if(remain>=off){ var when=tz.TZDateTime.now(tz.local).add(Duration(days: remain-off, hours: 8)); await flutterLocalNotificationsPlugin.zonedSchedule(id*10+i, '${item['name']} की Fatiha ${off==0 ? 'आज' : '$off दिन में'}', '${selDay} ${hMonths[selMonth]}', when, const NotificationDetails(android: AndroidNotificationDetails('fatiha_channel','Fatiha', importance: Importance.high)), androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime); } }
          setState(()=>fatihaList.add(item)); await saveData(); Navigator.pop(c);
        }, child: Text('Save', style: TextStyle(color: Colors.white))),
      ],
    )));
  }

  @override Widget build(BuildContext context){
    String islamicDateStr="12 - 05 - 1448";
    String engDate="24-10-2026";

    return Scaffold(
      backgroundColor: Color(0xFFE8F5E9),
      body: SingleChildScrollView(child: Column(children: [
        // DOME - सुबह वाला हूबहू - ऊपर से नीचे तक
        Container(
          width: double.infinity,
          height: 560, // पूरा दिखाने के लिए
          margin: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Color(0xFF0F4D24), width: 6),
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
          ),
          child: ClipPath(
            clipper: DomeClipper(),
            child: Container(
              color: Colors.white,
              child: Column(children: [
                SizedBox(height: 45),
                Text("JAMADIL AWAL", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F4D24))),
                SizedBox(height: 12),
                Text(islamicDateStr, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF0F4D24))),
                SizedBox(height: 10),
                Text("English Date: $engDate", style: TextStyle(fontSize: 14, color: Colors.grey)),
                SizedBox(height: 12),
                Container(height: 1, width: 280, color: Color(0xFF0F4D24)),
                SizedBox(height: 16),
                Text("NAMAZ TIME RANGE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F4D24))),
                SizedBox(height: 20),
                Text("Fajr  05:25 - 06:40", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F4D24))),
                SizedBox(height: 8),
                Text("Zuhr  12:25 - 16:30", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F4D24))),
                SizedBox(height: 8),
                Text("Asr  16:30 - 18:07", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F4D24))),
                SizedBox(height: 8),
                Text("Maghrib  18:07 - 19:23", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F4D24))),
                SizedBox(height: 8),
                Text("Isha  19:23 - 05:25", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F4D24))),
                Spacer(),
                // Buttons - Dome के अंदर सबसे नीचे
                Padding(
                  padding: EdgeInsets.fromLTRB(12,0,12,16),
                  child: Row(children: [
                    Expanded(child: ElevatedButton(onPressed: addFatihaDialog, style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0F4D24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: EdgeInsets.symmetric(vertical: 14)), child: Text("+ Add Fatiha", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)))),
                    SizedBox(width: 10),
                    Expanded(child: ElevatedButton(onPressed: addFatihaDialog, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, side: BorderSide(color: Color(0xFF0F4D24), width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: EdgeInsets.symmetric(vertical: 14)), child: Text("+ Add Urs", style: TextStyle(color: Color(0xFF0F4D24), fontWeight: FontWeight.bold, fontSize: 14)))),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        // FATIHA-URS LIST - सबसे नीचे
        Padding(padding: EdgeInsets.all(10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('MY FATIHA LIST (${fatihaList.length})', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F4D24))),
          Icon(Icons.share, color: Color(0xFF0F4D24)),
        ])),
        Container(
          margin: EdgeInsets.fromLTRB(10,0,10,20),
          height: 350,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Color(0xFF0F4D24))),
          child: fatihaList.isEmpty ? Center(child: Text('Add Fatiha दबाओ - सिर्फ Islamic Day+Month', style: TextStyle(fontSize: 12))) : ListView.builder(
            itemCount: fatihaList.length,
            itemBuilder: (c,i){
              var r=fatihaList[i];
              int days=daysRemain(r['iDay'], r['iMonth']);
              return ListTile(
                title: Text("${r['name']} - ${r['iDay'].toString().padLeft(2,'0')} ${hMonths[r['iMonth']]}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: getColor(days))),
                subtitle: Text("-> $days days remain", style: TextStyle(fontSize: 11)),
                trailing: IconButton(icon: Icon(Icons.delete, size: 18), onPressed: () async { setState(()=>fatihaList.removeAt(i)); await saveData(); }),
              );
            },
          ),
        ),
      ])),
    );
  }
}
