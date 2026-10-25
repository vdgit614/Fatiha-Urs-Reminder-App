import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(FatihaReminderApp());
}

class FatihaReminderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fatiha Urs Reminder',
      theme: ThemeData(
        primaryColor: Color(0xFF0B4D2E),
        scaffoldBackgroundColor: Color(0xFFFBF9F6),
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
  String cityName = 'Dabhoi';
  double latitude = 22.1833;
  double longitude = 73.4333;
  String todayHijri = '';
  String prayerInfo = 'Loading Namaz Time...';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    todayHijri = getIslamicDate();
    _checkAndAskPermission();
    loadManualOrAutoLocation();
  }

  String getIslamicDate() {
    var hijri = HijriCalendar.now();
    return '${hijri.hDay} ${hijri.longMonthName} ${hijri.hYear} Hijri';
  }

  Future<void> _checkAndAskPermission() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  Future<void> loadManualOrAutoLocation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool useManual = prefs.getBool('use_manual') ?? false;
    if (useManual) {
      double lat = prefs.getDouble('manual_lat') ?? 22.1833;
      double lon = prefs.getDouble('manual_lon') ?? 73.4333;
      String city = prefs.getString('manual_city') ?? 'Manual Location';
      calculateNamazRanges(lat, lon, city);
    } else {
      getUserLocationAndCalculate();
    }
  }
    Future<void> getUserLocationAndCalculate() async {
    setState(() => isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('GPS Off');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Denied');
      }
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      String city = marks.first.locality ?? marks.first.subAdministrativeArea ?? 'Current Location';
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('use_manual', false);
      calculateNamazRanges(pos.latitude, pos.longitude, city);
    } catch (e) {
      calculateNamazRanges(22.1833, 73.4333, 'Dabhoi (Default)');
    }
    setState(() => isLoading = false);
  }

  void calculateNamazRanges(double lat, double lon, String city) {
    final coords = Coordinates(lat, lon);
    final params = CalculationMethod.karachi.getParameters();
    params.madhab = Madhab.hanafi;
    final prayers = PrayerTimes.today(coords, params);
    setState(() {
      cityName = city;
      latitude = lat;
      longitude = lon;
      prayerInfo = 'Fajr ${DateFormat('h:mm a').format(prayers.fajr)} - ${DateFormat('h:mm a').format(prayers.sunrise)}';
    });
  }

  void loadData() {}

  Future<void> _showManualLocationDialog() async {
    final cityController = TextEditingController();
    final latController = TextEditingController();
    final lonController = TextEditingController();
    final prefs = await SharedPreferences.getInstance();
    cityController.text = prefs.getString('manual_city') ?? '';
    if (prefs.getDouble('manual_lat') != null) latController.text = prefs.getDouble('manual_lat').toString();
    if (prefs.getDouble('manual_lon') != null) lonController.text = prefs.getDouble('manual_lon').toString();
    ValueNotifier<String> cityNotifier = ValueNotifier(cityController.text);
    cityController.addListener(() {
      cityNotifier.value = cityController.text;
    });
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('स्थान दर्ज करें', style: TextStyle(color: Color(0xFF0B4D2E), fontWeight: FontWeight.bold, fontSize: 20)),
            IconButton(onPressed: () => Navigator.pop(ctx), icon: Icon(Icons.close)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('मेरा शहर (City Name)'),
              SizedBox(height: 6),
              TextField(
                controller: cityController,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.location_on_outlined, color: Color(0xFF0B4D2E)),
                  hintText: 'Mumbai',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              SizedBox(height: 15),
              ValueListenableBuilder<String>(
                valueListenable: cityNotifier,
                builder: (context, cityVal, _) {
                  String displayCity = cityVal.isEmpty ? '___' : cityVal;
                  String copyText = 'मेरे शहर $displayCity का latitude longitude बताइए';
                  return Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFDFF5E1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xFF0B4D2E).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(copyText, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF0B4D2E)))),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: copyText));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copy हो गया! Google में Paste करो!')));
                          },
                          child: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.copy, color: Color(0xFF0B4D2E))),
                        ),
                      ],
                    ),
                  );
                },
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Add latitude --'), SizedBox(height: 6), TextField(controller: latController, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(hintText: 'e.g. 19.0760', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))])),
                  SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Add longitude --'), SizedBox(height: 6), TextField(controller: lonController, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(hintText: 'e.g. 72.8777', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))])),
                ],
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0B4D2E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    String city = cityController.text.trim();
                    double? lat = double.tryParse(latController.text.trim());
                    double? lon = double.tryParse(lonController.text.trim());
                    if (city.isEmpty || lat == null || lon == null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('सभी Field भरो!')));
                      return;
                    }
                    await prefs.setString('manual_city', city);
                    await prefs.setDouble('manual_lat', lat);
                    await prefs.setDouble('manual_lon', lon);
                    await prefs.setBool('use_manual', true);
                    Navigator.pop(ctx);
                    calculateNamazRanges(lat, lon, city);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$city Save हो गया!')));
                  },
                  child: Text('सेव करें', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
    @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Fatiha Urs Reminder'), backgroundColor: Color(0xFF0B4D2E), foregroundColor: Colors.white),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF0B4D2E)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.mosque, color: Colors.white, size: 40),
                SizedBox(height: 10),
                Text('Fatiha Reminder', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('$cityName', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ),
            ListTile(
              leading: Icon(Icons.my_location, color: Color(0xFF0B4D2E)),
              title: Text('Refresh Location (Auto)'),
              subtitle: Text('GPS से लोकेशन लो', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                getUserLocationAndCalculate();
              },
            ),
            ListTile(
              leading: Icon(Icons.edit_location_alt, color: Colors.orange[800]),
              title: Text('Add Location Manually', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('शहर खुद डालो - बिना GPS', style: TextStyle(fontSize: 11)),
              tileColor: Colors.orange[50],
              onTap: () {
                Navigator.pop(context);
                _showManualLocationDialog();
              },
            ),
            Divider(),
            ListTile(leading: Icon(Icons.info_outline), title: Text('About App')),
          ],
        ),
      ),
      body: Center(
        child: isLoading
            ? CircularProgressIndicator(color: Color(0xFF0B4D2E))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(todayHijri, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  SizedBox(height: 10),
                  Text(cityName, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0B4D2E))),
                  Text('${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 20),
                  Card(
                    margin: EdgeInsets.all(20),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(prayerInfo, style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
