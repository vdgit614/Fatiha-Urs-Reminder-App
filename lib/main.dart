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
  @override bool shouldReclip(old) => false;
}

class HomeScreen extends StatefulWidget { @override _HomeScreenState createState()=>_HomeScreenState(); }

class _HomeScreenState extends State<HomeScreen> {
  late HijriCalendar todayHijri;
  late PrayerTimes prayerTimes;
  List<Map<String,dynamic>> fatihaList=[];
  bool showFatihaList = false; // By Default OFF
  List<String> hMonths=["", "MUHARRAM","SAFAR","RABI-UL-AWWAL","RABI-UL-AAKHAR","JAMADIL AWAL","JAMADIL AAKHAR","RAJJAB","SHABAN","RAMZAN","SHAWWAL","ZIL-QAD","ZIL-HAJJ"];

  @override void initState(){
    super.initState();
    todayHijri=HijriCalendar.now(); 
    try { todayHijri.hDay=todayHijri.hDay-1; } catch(_){}
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

  Future<void> addFatihaDialog() async {
    TextEditingController nameCtrl=TextEditingController();
    int selDay=todayHijri.hDay, selMonth=todayHijri.hMonth;
    await showDialog(context: context, builder: (c)=>StatefulBuilder(builder: (c,setD)=>AlertDialog(
      title: Text('ADD FATIHA', style: TextStyle(color: Color(0xFF0F4D24), fontWeight: FontWeight.bold, font
