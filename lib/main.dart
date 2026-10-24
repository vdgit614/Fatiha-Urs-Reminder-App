import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:adhan/adhan.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  try { tz.setLocalLocation(tz.getLocation('Asia/Kolkata')); } catch (_) {}
  try {
    const AndroidInitializationSettings initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    await flutterLocalNotificationsPlugin.initialize(const InitializationSettings(android: initAndroid));
  } catch (_) {}
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: HomeScreen()));
}

// आपका Original Dome - वही रहेगा
class FullArchClipper extends CustomClipper<Path> {
  @override Path getClip(Size size) {
    double w=size.width,h=size.height;
    Path path=Path();
    path.moveTo(w/2,0);
    path.cubicTo(w*0.65,h*0.08,w,h*0.18,w,h*0.30);
    path.lineTo(w,h); path.lineTo(0,h); path.lineTo(0,h*0.30);
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
    path.lineTo(w,h); path.lineTo(0,h); path.lineTo(0,h*0.30);
    path.cubicTo(0,h*0.18,w*0.35,h*0.08,w/2,0); path.close();
    canvas.drawShadow(path, Colors.black26, 10, true);
    Paint fill=Paint()..color=Colors.white..style=PaintingStyle.fill;
    Paint border=Paint()..color=Color(0xFF0F4D24)..style=PaintingStyle.stroke..strokeWidth=12..strokeJoin=StrokeJoin.round;
    canvas.drawPath(path, fill); canvas.drawPath(path, border);
  }
  @override bool shouldRepaint(old)=>false;
}

class HomeScreen extends StatefulWidget { @override _HomeScreenState createState()=>_HomeScreenState(); }

class _HomeScreenState extends State<HomeScreen> {
  late HijriCalendar todayHijri;
  late PrayerTimes prayerTimes;
  String adminPin="78692";
  bool isFetchingGuj=false;

  // Month Map - gujchand.com के नाम से हमारे नंबर पर
  Map<String,int> monthMap={
    'muharram':1, 'safar':2, 'rabi-ul-awwal':3, 'rabi-ul-akhir':3, 'rabi':3,
    'jamad-ul-awwal':5, 'jamadil awal':5, 'jamad-ul-akhir':6, 'jamadil thani':6,
    'rajab':7, 'shaban':8, 'ramzan':9, 'ramadan':9, 'shawwal':10, 'shawal':10,
    'zil-qad':11, 'jilqad':11, 'zil-hajj':12, 'jilhajj':12, 'zilhaj':12
  };

  @override void initState(){
    super.initState();
    todayHijri=HijriCalendar.now();
    todayHijri.hDay=todayHijri.hDay-1; // Gujarat fix
    calcPrayerTimes();
    loadGujChandDate();
  }

  void calcPrayerTimes(){
    final coords=Coordinates(23.0225,72.5714);
    final params=CalculationMethod.karachi.getParameters(); params.madhab=Madhab.hanafi;
    prayerTimes=PrayerTimes.today(coords, params);
  }

  Future<void> loadGujChandDate() async {
    SharedPreferences prefs=await SharedPreferences.getInstance();
    
    // 1. पहले Local Saved देखो
    if(prefs.containsKey('gujchand_auto')){
      try{
        var saved=json.decode(prefs.getString('gujchand_auto')!);
        DateTime savedTime=DateTime.parse(saved['time']);
        // अगर आज ही Save किया है तो वही दिखाओ
        if(DateTime.now().difference(savedTime).inHours < 12){
          setState((){
            todayHijri.hDay=saved['day'];
            todayHijri.hMonth=saved['month'];
            todayHijri.hYear=saved['year'];
          });
        }
      }catch(_){}
    }

    // 2. Admin Manual Override - Emergency
    if(prefs.containsKey('admin_hijri_guj')){
      var admin=json.decode(prefs.getString('admin_hijri_guj')!);
      setState((){
        todayHijri.hDay=admin['day']; todayHijri.hMonth=admin['month']; todayHijri.hYear=admin['year'];
      });
      return;
    }

    // 3. Logic: 1-26 तक Sunset+15, 27,28,29 को 7PM बाद Website
    DateTime now=DateTime.now();
    DateTime sunset15=prayerTimes.maghrib.add(Duration(minutes:15));
    
    if(todayHijri.hDay <= 26){
      if(now.isAfter(sunset15)){
        // आज Maghrib हो गई, कल की Date
        if(prefs.containsKey('last_sunset_check')){
          DateTime last=DateTime.parse(prefs.getString('last_sunset_check')!);
          if(last.day!=now.day){
            setState(()=>todayHijri.hDay+=1);
            saveAuto();
          }
        } else {
          prefs.setString('last_sunset_check', now.toIso8601String());
        }
      }
    } else {
      // 27,28,29 - शाम 7 बजे बाद gujchand.com
      if(now.hour >= 19){
        await fetchFromGujChand();
      }
    }
  }

  Future<void> saveAuto() async {
    SharedPreferences prefs=await SharedPreferences.getInstance();
    prefs.setString('gujchand_auto', json.encode({'day':todayHijri.hDay,'month':todayHijri.hMonth,'year':todayHijri.hYear,'time':DateTime.now().toIso8601String()}));
    prefs.setString('last_sunset_check', DateTime.now().toIso8601String());
  }

  // === GUJCHAND.COM AUTO READER ===
  Future<void> fetchFromGujChand() async {
    if(isFetchingGuj) return;
    setState(()=>isFetchingGuj=true);
    try{
      final res=await http.get(Uri.parse('https://gujchand.com/')).timeout(Duration(seconds:15));
      if(res.statusCode==200){
        var doc=html_parser.parse(res.body);
        String fullText=doc.body!.text; // पूरा Text
        
        // Screenshot वाला Pattern: "12 Jamad-ul-awwal 1448 Hijri"
        // Regex: Day + Month Name + Year
        RegExp reg=RegExp(r'(\d{1,2})\s+([A-Za-z\-]+)\s+(\d{4})\s+Hijri', caseSensitive:false);
        var match=reg.firstMatch(fullText);
        
        if(match!=null){
          int day=int.parse(match.group(1)!);
          String monthName=match.group(2)!.toLowerCase().trim();
          int year=int.parse(match.group(3)!);
          
          int monthNum=5; // default
          monthMap.forEach((k,v){
            if(monthName.contains(k) || k.contains(monthName)){
              monthNum=v;
            }
          });
          
          // मिला! gujchand.com की Date
          setState((){
            todayHijri.hDay=day;
            todayHijri.hMonth=monthNum;
            todayHijri.hYear=year;
          });
          SharedPreferences.getInstance().then((prefs){
            prefs.setString('gujchand_auto', json.encode({'day':day,'month':monthNum,'year':year,'time':DateTime.now().toIso8601String()}));
          });
          debugPrint('GujChand Auto Success: $day - $monthNum - $year');
        }
      }
    }catch(e){ debugPrint('GujChand Fail $e'); }
    setState(()=>isFetchingGuj=false);
  }

  void openAdminCheck(){
    TextEditingController pinCtrl=TextEditingController();
    showDialog(context: context, builder: (c)=>AlertDialog(
      title: Text('Admin PIN (GujChand Fail होने पर)'),
      content: TextField(controller: pinCtrl, obscureText:true, decoration: InputDecoration(hintText:'PIN')),
      actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: Text('Cancel')), ElevatedButton(onPressed: (){ if(pinCtrl.text==adminPin){ Navigator.pop(c); openAdminPanel(); } }, child: Text('OK'))],
    ));
  }
  void openAdminPanel(){
    int d=todayHijri.hDay,m=todayHijri.hMonth,y=todayHijri.hYear;
    showDialog(context: context, builder: (c)=>AlertDialog(
      title: Text('gujchand.com से Date डालो'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(decoration: InputDecoration(labelText:'Day (12)'), keyboardType:TextInputType.number, controller: TextEditingController(text:d.toString()), onChanged:(v)=>d=int.tryParse(v)??d),
        TextField(decoration: InputDecoration(labelText:'Month (5=Jamad-ul-awwal)'), keyboardType:TextInputType.number, controller: TextEditingController(text:m.toString()), onChanged:(v)=>m=int.tryParse(v)??m),
      ]),
      actions: [ElevatedButton(onPressed: () async { SharedPreferences prefs=await SharedPreferences.getInstance(); prefs.setString('admin_hijri_guj', json.encode({'day':d,'month':m,'year':y})); setState(()=>todayHijri.hDay=d); Navigator.pop(c); }, child: Text('Save'))],
    ));
  }

  @override Widget build(BuildContext context){
    double sw=MediaQuery.of(context).size.width, sh=MediaQuery.of(context).size.height;
    List<String> hMonths=["", "MUHARRAM","SAFAR","RABI-AL-AWWAL","RABI-AL-THANI","JAMADIL AWAL","JAMADIL THANI","RAJAB","SHABAN","RAMZAN","SHAWWAL","ZIL-QAD","ZIL-HAJJ"];
    String islamicDateStr="${todayHijri.hDay.toString().padLeft(2,'0')} - ${todayHijri.hMonth.toString().padLeft(2,'0')} - ${todayHijri.hYear}";
    String islamicMonthStr=hMonths[todayHijri.hMonth];
    String engDate="${DateTime.now().day.toString().padLeft(2,'0')}-${DateTime.now().month.toString().padLeft(2,'0')}-${DateTime.now().year}";
    String fajr="${prayerTimes.fajr.hour.toString().padLeft(2,'0')}:${prayerTimes.fajr.minute.toString().padLeft(2,'0')} - ${prayerTimes.sunrise.hour.toString().padLeft(2,'0')}:${prayerTimes.sunrise.minute.toString().padLeft(2,'0')}";
    String zuhr="${prayerTimes.dhuhr.hour.toString().padLeft(2,'0')}:${prayerTimes.dhuhr.minute.toString().padLeft(2,'0')} - ${prayerTimes.asr.hour.toString().padLeft(2,'0')}:${prayerTimes.asr.minute.toString().padLeft(2,'0')}";
    String asr="${prayerTimes.asr.hour.toString().padLeft(2,'0')}:${prayerTimes.asr.minute.toString().padLeft(2,'0')} - ${prayerTimes.maghrib.hour.toString().padLeft(2,'0')}:${prayerTimes.maghrib.minute.toString().padLeft(2,'0')}";
    String maghrib="${prayerTimes.maghrib.hour.toString().padLeft(2,'0')}:${prayerTimes.maghrib.minute.toString().padLeft(2,'0')} - ${prayerTimes.isha.hour.toString().padLeft(2,'0')}:${prayerTimes.isha.minute.toString().padLeft(2,'0')}";
    String isha="${prayerTimes.isha.hour.toString().padLeft(2,'0')}:${prayerTimes.isha.minute.toString().padLeft(2,'0')} - ${prayerTimes.fajr.hour.toString().padLeft(2,'0')}:${prayerTimes.fajr.minute.toString().padLeft(2,'0')}";

    return Scaffold(
      backgroundColor: Color(0xFFF2F7F2),
      body: SafeArea(child: Padding(padding: EdgeInsets.all(8), child: Column(children: [
        Expanded(child: CustomPaint(
          painter: FullArchPainter(),
          child: ClipPath(
            clipper: FullArchClipper(),
            child: Container(width: sw, height: sh*0.82, child: Column(children: [
              SizedBox(height: sh*0.12),
              Text(islamicMonthStr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F4D24))),
              SizedBox(height: 14),
              Text(islamicDateStr, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F4D24))),
              if(isFetchingGuj) Text("GujChand से Auto Update...", style: TextStyle(fontSize: 10, color: Colors.grey)),
              SizedBox(height: 28),
              Text("English Date: $engDate", style: TextStyle(fontSize: 13, color: Colors.grey)),
              SizedBox(height: 10),
              Divider(indent: 50, endIndent: 50, thickness: 1, color: Color(0xFF0F4D24)),
              SizedBox(height: 10),
              GestureDetector(onLongPress: openAdminCheck, child: Text("NAMAZ TIME RANGE", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F4D24)))),
              SizedBox(height: 20),
              _row("Fajr", fajr), _row("Zuhr", zuhr), _row("Asr", asr), _row("Maghrib", maghrib), _row("Isha", isha),
              Spacer(),
              Padding(padding: EdgeInsets.fromLTRB(12,0,12,22), child: Row(children: [
                Expanded(child: SizedBox(height: 50, child: ElevatedButton(onPressed: (){}, style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0F4D24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text("+ Add Fatiha", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))),
                SizedBox(width: 10),
                Expanded(child: SizedBox(height: 50, child: ElevatedButton(onPressed: (){}, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, side: BorderSide(color: Color(0xFF0F4D24), width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text("+ Add Urs", style: TextStyle(color: Color(0xFF0F4D24), fontWeight: FontWeight.bold))))),
              ])),
            ])),
          ),
        )),
      ]))),
    );
  }
  Widget _row(String n,String t)=>Padding(padding: EdgeInsets.symmetric(vertical:6), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width:80, child: Text(n, textAlign:TextAlign.right, style: TextStyle(fontSize:16, fontWeight:FontWeight.bold, color:Color(0xFF0F4D24)))), SizedBox(width:12), Text(t, style: TextStyle(fontSize:16, color:Color(0xFF0F4D24)))]));
}
