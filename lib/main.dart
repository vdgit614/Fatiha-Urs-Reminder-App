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
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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
    path.moveTo(w/2,0);
    path.cubicTo(w*0.65,h*0.08,w,h*0.18,w,h*0.30);
    path.lineTo(w,h); path.lineTo(0,h); path.lineTo(0,h*0.30);
    path.cubicTo(0,h*0.18,w*0.35,h*0.08,w/2,0);
    path.close(); return path;
  }
  @override bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

class FullArchPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size size) {
    double w = size.width; double h = size.height;
    Path path = Path();
    path.moveTo(w/2,0);
    path.cubicTo(w*0.65,h*0.08,w,h*0.18,w,h*0.30);
    path.lineTo(w,h); path.lineTo(0,h); path.lineTo(0,h*0.30);
    path.cubicTo(0,h*0.18,w*0.35,h*0.08,w/2,0);
    path.close();
    canvas.drawShadow(path, Colors.black26, 10, true);
    Paint fill = Paint()..color = Colors.white..style = PaintingStyle.fill;
    Paint border = Paint()..color = Color(0xFF0F4D24)..style = PaintingStyle.stroke..strokeWidth = 6..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, fill); canvas.drawPath(path, border);
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}

class HomeScreen extends StatefulWidget { @override _HomeScreenState createState()=>_HomeScreenState(); }

class _HomeScreenState extends State<HomeScreen> {
  late HijriCalendar todayHijri;
  List<Map<String,dynamic>> fatihaList=[];
  bool showFatihaList = false;
  List<String> hMonths=["", "MUHARRAM","SAFAR","RABI-UL-AWWAL","RABI-UL-AAKHAR","JAMADIL AWAL","JAMADIL AAKHAR","RAJJAB","SHABAN","RAMZAN","SHAWWAL","ZIL-QAD","ZIL-HAJJ"];
  String fajrRange="Locating...";
  String zuhrRange="Locating...";
  String asrRange="Locating...";
  String maghribRange="Locating...";
  String ishaRange="Locating...";
  String currentCity="Ahmedabad";

  @override void initState(){
    super.initState();
    todayHijri=getIslamicDate();
    loadData();
    getUserLocationAndCalculate();
  }

  Future<void> getUserLocationAndCalculate({bool showLoading = false}) async {
    if(showLoading){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location le rahe hain... GPS ON rakho'), duration: Duration(seconds: 2)));
    }
    try{
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if(!serviceEnabled){
        if(showLoading) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location Service OFF hai! Settings me ON karo')));
        calculateNamazRanges(23.0225, 72.5714, "Ahmedabad");
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if(permission == LocationPermission.denied){
        permission = await Geolocator.requestPermission();
        if(permission == LocationPermission.denied){
          if(showLoading) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location Permission Deny kiya! Allow karo')));
          calculateNamazRanges(23.0225, 72.5714, "Ahmedabad");
          return;
        }
      }
      if(permission == LocationPermission.deniedForever){
        if(showLoading){
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Permission permanently deny hai! App Settings me jake Allow karo'), duration: Duration(seconds: 4)));
          await Geolocator.openAppSettings();
        }
        calculateNamazRanges(23.0225, 72.5714, "Ahmedabad");
        return;
      }
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium).timeout(Duration(seconds: 15));
      String cityName = "Your Location";
      try{
        List<Placemark> placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if(placemarks.isNotEmpty){
          cityName = placemarks[0].locality ?? placemarks[0].subLocality ?? placemarks[0].administrativeArea ?? "Your Location";
        }
      }catch(e){
        cityName = "Lat ${pos.latitude.toStringAsFixed(2)}";
      }
      calculateNamazRanges(pos.latitude, pos.longitude, cityName);
      if(showLoading){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location Update: $cityName'), backgroundColor: Color(0xFF0F4D24)));
      }
    }catch(e){
      if(showLoading) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location Error - Ahmedabad dikhaya')));
      calculateNamazRanges(23.0225, 72.5714, "Ahmedabad");
    }
  }

  String format12(DateTime dt){
    int h=dt.hour; String ampm=h>=12?"PM":"AM";
    int hour12=h%12; if(hour12==0) hour12=12;
    String m=dt.minute.toString().padLeft(2,'0');
    return "$hour12:$m $ampm";
  }

  void calculateNamazRanges(double lat, double lon, String city){
    try{
      final coords=Coordinates(lat, lon);
      final params=CalculationMethod.karachi.getParameters();
      params.madhab=Madhab.hanafi;
      final prayerTimes=PrayerTimes.today(coords,params);
      setState((){
        currentCity = city;
        fajrRange=format12(prayerTimes.fajr)+" - "+format12(prayerTimes.sunrise);
        zuhrRange=format12(prayerTimes.dhuhr)+" - "+format12(prayerTimes.asr);
        asrRange=format12(prayerTimes.asr)+" - "+format12(prayerTimes.maghrib);
        maghribRange=format12(prayerTimes.maghrib)+" - "+format12(prayerTimes.isha);
        ishaRange=format12(prayerTimes.isha)+" - "+format12(prayerTimes.fajr.add(Duration(days:1)));
      });
    }catch(e){}
  }
    HijriCalendar getIslamicDate(){
    HijriCalendar hijri=HijriCalendar.now(); hijri.hDay=hijri.hDay-1;
    try{
      final coords=Coordinates(23.0225,72.5714);
      final params=CalculationMethod.karachi.getParameters(); params.madhab=Madhab.hanafi;
      final prayerTimes=PrayerTimes.today(coords,params);
      final maghrib=prayerTimes.maghrib;
      if(maghrib!=null){
        final changeTime=maghrib.add(Duration(minutes:15));
        if(DateTime.now().isAfter(changeTime)){
          int day=hijri.hDay+1; int month=hijri.hMonth; int year=hijri.hYear;
          if(day>30){ day=1; month++; if(month>12){ month=1; year++; } }
          hijri.hDay=day; hijri.hMonth=month; hijri.hYear=year;
        }
      }
    }catch(e){} return hijri;
  }

  Future<void> loadData() async { SharedPreferences prefs=await SharedPreferences.getInstance(); if(prefs.containsKey('fatiha_list')){ setState(()=>fatihaList=List<Map<String,dynamic>>.from(json.decode(prefs.getString('fatiha_list')!))); } }
  Future<void> saveData() async { SharedPreferences prefs=await SharedPreferences.getInstance(); prefs.setString('fatiha_list', json.encode(fatihaList)); }
  int daysRemain(int tDay, int tMonth){ int todayTotal=(todayHijri.hMonth-1)*30 + todayHijri.hDay; int targetTotal=(tMonth-1)*30 + tDay; int diff=targetTotal - todayTotal; if(diff<0) diff+=360; return diff; }
  Color getColor(int days){ if(days<=7) return Color(0xFFD32F2F); if(days<=60) return Color(0xFFE65100); return Color(0xFF0F4D24); }

  Future<void> backupToDrive() async {
    if(fatihaList.isEmpty){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("List Empty"))); return; }
    try{
      String jsonData = json.encode(fatihaList);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/fatiha_backup.json');
      await file.writeAsString(jsonData);
      await Share.shareXFiles([XFile(file.path)], text: "MY FATIHA LIST BACKUP - ${fatihaList.length} Fatiha");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Backup Ready - Drive Select karo")));
    }catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Backup Failed: $e"))); }
  }

  Future<void> restoreFromDrive() async {
    try{
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if(result != null){
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        List data = json.decode(content);
        setState(()=>fatihaList = List<Map<String,dynamic>>.from(data));
        await saveData();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${data.length} Fatiha Restore Ho Gayi")));
      }
    }catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Restore Failed: $e"))); }
  }

  Future<void> shareFullList() async {
    if(fatihaList.isEmpty){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("List Empty"))); return; }
    try{ final dir = await getApplicationDocumentsDirectory(); final file = File('${dir.path}/fatiha_backup.json'); await file.writeAsString(json.encode(fatihaList)); await Share.shareXFiles([XFile(file.path)], text: "MY FATIHA LIST"); }catch(e){ String text="MY FATIHA LIST\n\n"; for(var r in fatihaList){ text+="${r['name']} - ${r['iDay']} ${hMonths[r['iMonth']]}\n"; } Share.share(text); }
  }

  Future<void> importList() async {
    try{ FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']); if(result != null){ File file = File(result.files.single.path!); String content = await file.readAsString(); List data = json.decode(content); setState(()=>fatihaList = List<Map<String,dynamic>>.from(data)); await saveData(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${data.length} Fatiha Import hui"))); } }catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Import Failed: $e"))); }
  }

  Future<void> addFatihaDialog() async {
    TextEditingController nameCtrl=TextEditingController(); int selDay=todayHijri.hDay; int selMonth=todayHijri.hMonth;
    await showDialog(context: context, builder: (ctx){ return StatefulBuilder(builder: (ctx2, setD){ return AlertDialog(title: Text('ADD FATIHA', style: TextStyle(color: Color(0xFF0F4D24), fontWeight: FontWeight.bold, fontSize: 14)), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'add name here', border: OutlineInputBorder())), SizedBox(height: 12), Row(children: [Expanded(child: DropdownButtonFormField<int>(value: selDay, decoration: InputDecoration(labelText: 'Day'), items: List.generate(30, (i)=>DropdownMenuItem(value: i+1, child: Text("${i+1}"))), onChanged: (v)=>setD(()=>selDay=v!))), SizedBox(width: 8), Expanded(flex: 2, child: DropdownButtonFormField<int>(value: selMonth, decoration: InputDecoration(labelText: 'Month'), items: List.generate(12, (i)=>DropdownMenuItem(value: i+1, child: Text(hMonths[i+1], style: TextStyle(fontSize: 10)))), onChanged: (v)=>setD(()=>selMonth=v!)))])]), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: Text('Cancel')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0F4D24)), onPressed: () async { if(nameCtrl.text.trim().isEmpty) return; int id=DateTime.now().millisecondsSinceEpoch.remainder(100000); Map<String,dynamic> item={'id':id, 'name':nameCtrl.text.trim(), 'iDay':selDay, 'iMonth':selMonth}; int remain=daysRemain(selDay, selMonth); for(int i=0;i<3;i++){ int off=[7,1,0][i]; if(remain>=off){ var when=tz.TZDateTime.now(tz.local).add(Duration(days: remain-off, hours: 8)); await flutterLocalNotificationsPlugin.zonedSchedule(id*10+i, item['name'] + " ki Fatiha", "${selDay} ${hMonths[selMonth]}", when, const NotificationDetails(android: AndroidNotificationDetails('fatiha_channel','Fatiha', importance: Importance.high)), androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime); } } setState(()=>fatihaList.add(item)); await saveData(); Navigator.pop(ctx); }, child: Text('Save', style: TextStyle(color: Colors.white)))], ); }); });
  }
    @override Widget build(BuildContext context){
    double sw = MediaQuery.of(context).size.width; double sh = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Color(0xFFF2F7F2),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: Builder(builder: (ctx) => IconButton(icon: Icon(Icons.menu, color: Color(0xFF0F4D24), size: 28), onPressed: ()=>Scaffold.of(ctx).openDrawer()))),
      drawer: Drawer(child: ListView(padding: EdgeInsets.zero, children: [
        DrawerHeader(decoration: BoxDecoration(color: Color(0xFF0F4D24)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.mosque, color: Colors.white, size: 40), SizedBox(height: 10), Text('Fatiha Reminder', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), Text(currentCity, style: TextStyle(color: Colors.white70, fontSize: 12))])),
        ListTile(leading: Icon(Icons.my_location, color: Color(0xFF0F4D24)), title: Text('Refresh Location', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), subtitle: Text('Location se Namaz Time update', style: TextStyle(fontSize: 11)), onTap: (){ Navigator.pop(context); getUserLocationAndCalculate(showLoading: true); }),
        ListTile(leading: Icon(Icons.cloud_upload, color: Color(0xFF0F4D24)), title: Text('Backup to Google Drive', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), subtitle: Text('1 Click me Drive par save kare', style: TextStyle(fontSize: 11)), onTap: (){ Navigator.pop(context); backupToDrive(); }),
        ListTile(leading: Icon(Icons.cloud_download, color: Color(0xFF0F4D24)), title: Text('Restore from Drive', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), subtitle: Text('Backup file se wapas laye', style: TextStyle(fontSize: 11)), onTap: (){ Navigator.pop(context); restoreFromDrive(); }),
        Divider(),
        ListTile(
          leading: Icon(Icons.info_outline, color: Color(0xFF0F4D24)),
          title: Text('About', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          onTap: (){
            Navigator.pop(context);
            showDialog(context: context, builder: (c)=>AlertDialog(
              title: Text('About', style: TextStyle(color: Color(0xFF0F4D24), fontWeight: FontWeight.bold)),
              content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Fatiha Reminder App\nVersion 1.0\nLocation: $currentCity\n\nYe App Marhoomo ki Fatiha yaad dilane ke liye banayi gayi hai.\n\nAllah sab Marhoomo ki Maghfirat farmaye. Ameen.\n', style: TextStyle(fontSize: 13)),
                Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Color(0xFFF2F7F2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Color(0xFF0F4D24))), child: Row(children: [Icon(Icons.email, color: Color(0xFF0F4D24), size: 20), SizedBox(width: 8), Expanded(child: Text('appvd.83@gmail.com', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F4D24))))])),
                SizedBox(height: 12),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0F4D24)), icon: Icon(Icons.send, color: Colors.white, size: 16), label: Text('Email Us', style: TextStyle(color: Colors.white)), onPressed: () async { final Uri emailUri = Uri(scheme: 'mailto', path: 'appvd.83@gmail.com', query: 'subject=Fatiha App - Help&body=Assalamu Alaikum,'); if (await canLaunchUrl(emailUri)) { await launchUrl(emailUri); }})),
              ]),
              actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: Text('Close'))],
            ));
          },
        ),
      ])),
      body: SafeArea(child: Padding(padding: EdgeInsets.all(8), child: Column(children: [
        Expanded(child: CustomPaint(painter: FullArchPainter(), child: ClipPath(clipper: FullArchClipper(), child: Container(width: sw, height: sh * 0.82, child: Column(children: [SizedBox(height: sh * 0.08), Text(hMonths[todayHijri.hMonth], style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F4D24))), SizedBox(height: 14), Text("${todayHijri.hDay.toString().padLeft(2,'0')} - ${todayHijri.hMonth.toString().padLeft(2,'0')} - ${todayHijri.hYear}", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F4D24))), SizedBox(height: 6), Text(currentCity, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F4D24))), Text("English Date: ${DateTime.now().day.toString().padLeft(2,'0')}-${DateTime.now().month.toString().padLeft(2,'0')}-${DateTime.now().year}", style: TextStyle(fontSize: 11, color: Colors.grey)), SizedBox(height: 8), Container(height: 1, width: 280, color: Color(0xFF0F4D24)), SizedBox(height: 10), Text("NAMAZ TIME RANGE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F4D24))), SizedBox(height: 18), Text("Fajr  $fajrRange", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F4D24))), SizedBox(height: 8), Text("Zuhr  $zuhrRange", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F4D24))), SizedBox(height: 8), Text("Asr  $asrRange", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F4D24))), SizedBox(height: 8), Text("Maghrib  $maghribRange", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F4D24))), SizedBox(height: 8), Text("Isha  $ishaRange", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F4D24))), Spacer(), Padding(padding: EdgeInsets.fromLTRB(12, 0, 12, 22), child: Row(children: [Expanded(child: SizedBox(height: 50, child: ElevatedButton(onPressed: addFatihaDialog, style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0F4D24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text("+ Add Fatiha", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))), SizedBox(width: 10), Expanded(child: SizedBox(height: 50, child: ElevatedButton(onPressed: addFatihaDialog, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, side: BorderSide(color: Color(0xFF0F4D24), width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text("+ Add Urs", style: TextStyle(color: Color(0xFF0F4D24), fontWeight: FontWeight.bold))))), ])), ])), ))),
        Container(color: Colors.white, margin: EdgeInsets.fromLTRB(0,8,0,0), padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Text('MY FATIHA LIST (${fatihaList.length})', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F4D24), fontSize: 11)), SizedBox(width: 6), Switch(value: showFatihaList, activeColor: Color(0xFF0F4D24), onChanged: (v){ setState(()=>showFatihaList=v); }), Text(showFatihaList ? 'ON' : 'OFF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: showFatihaList ? Color(0xFF0F4D24) : Colors.grey))]), Row(children: [IconButton(icon: Icon(Icons.download, color: Color(0xFF0F4D24), size: 20), onPressed: importList), IconButton(icon: Icon(Icons.share, color: Color(0xFF0F4D24), size: 20), onPressed: shareFullList)])])),
        AnimatedContainer(duration: Duration(milliseconds: 300), height: showFatihaList ? 300 : 0, child: showFatihaList ? Container(margin: EdgeInsets.fromLTRB(0,0,0,0), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Color(0xFF0F4D24))), child: fatihaList.isEmpty ? Center(child: Text('No Fatiha')) : ListView.builder(itemCount: fatihaList.length, itemBuilder: (c,i){ var r=fatihaList[i]; int days=daysRemain(r['iDay'], r['iMonth']); return ListTile(dense: true, title: Text("${r['name']} - ${r['iDay']} ${hMonths[r['iMonth']]}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: getColor(days))), subtitle: Text("-> $days days remain", style: TextStyle(fontSize: 11)), trailing: IconButton(icon: Icon(Icons.delete, size: 18), onPressed: () async { setState(()=>fatihaList.removeAt(i)); await saveData(); })); })) : SizedBox.shrink()),
      ]))),
    );
  }
}
