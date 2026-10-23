import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  
  runApp(FatihaUrsApp());
}

class FatihaUrsApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fatiha Urs Reminder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Color(0xFF006400),
        scaffoldBackgroundColor: Color(0xFFF5F5DC),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF006400),
          foregroundColor: Colors.white,
        ),
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> reminders = [];
  TextEditingController nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadReminders();
    requestPermission();
  }

  Future<void> requestPermission() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> loadReminders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('reminders');
    if (data != null) {
      setState(() {
        reminders = List<Map<String, dynamic>>.from(json.decode(data));
      });
    }
  }

  Future<void> saveReminders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('reminders', json.encode(reminders));
  }

  Future<void> scheduleNotification(int id, String title, DateTime dateTime) async {
    await
