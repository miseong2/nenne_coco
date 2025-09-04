import 'package:nenne_coco/lock_screen.dart';
import 'package:nenne_coco/scan_screen.dart';
import 'package:nenne_coco/settings_page.dart';
import 'package:nenne_coco/video_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'package:nenne_coco/recording_page.dart';
import 'background_service.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeBackgroundService();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  double _textScaleFactor = 1.0;

  @override
  void initState() {
    super.initState();
    _loadTextScaleFactor();
  }

  Future<void> _loadTextScaleFactor() async {
    final prefs = await SharedPreferences.getInstance();
    final savedScale = prefs.getDouble('textScale');
    setState(() {
      _textScaleFactor = savedScale ?? 1.0;
    });
  }

  Future<void> _saveTextScaleFactor(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('textScale', scale);
  }

  void _updateTextScaleFactor(double newScale) {
    setState(() {
      _textScaleFactor = newScale;
    });
    _saveTextScaleFactor(newScale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '낸내코코',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6CA4C8)),
        scaffoldBackgroundColor: Colors.blueGrey[30],
        useMaterial3: true,
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(_textScaleFactor),
          ),
          child: child!,
        );
      },
      home: AuthGate(
        updateTextScale: _updateTextScaleFactor,
        textScaleFactor: _textScaleFactor,
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  final Function(double) updateTextScale;
  final double textScaleFactor;

  const AuthGate({
    super.key,
    required this.updateTextScale,
    required this.textScaleFactor,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLocked = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLockStatus();
  }

  Future<void> _checkLockStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLocked = prefs.getBool('isLocked') ?? false;
      _isLoading = false;
    });
  }

  void _unlockApp() {
    setState(() {
      _isLocked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isLocked) {
      return LockScreen(onUnlock: _unlockApp);
    } else {
      return MainScreen(
        updateTextScale: widget.updateTextScale,
        textScaleFactor: widget.textScaleFactor,
      );
    }
  }
}

class MainScreen extends StatefulWidget {
  final Function(double) updateTextScale;
  final double textScaleFactor;

  const MainScreen({
    super.key,
    required this.updateTextScale,
    required this.textScaleFactor,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.blueGrey[30],
            appBar: AppBar(
        toolbarHeight: 75.0,
        backgroundColor: const Color(0xFF6CA4C8),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('낸내코코', style: TextStyle(color: Colors.white, fontSize: 22.0)),
            Text('infant safety notification system', style: TextStyle(color: Colors.white, fontSize: 14.0)),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          const Spacer(flex: 3),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VideoPage()),
              );
            },
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 40.0),
                  child: Image.asset(
                    'assets/babyIcon.png',
                    width: 200,
                    height: 200,
                  ),
                ),
                Positioned(
                  top: -15,
                  child: CustomPaint(
                    painter: SpeechBubblePainter(
                      bubbleColor: Colors.white,
                      borderColor: const Color(0xFF6CA4C8),
                      borderWidth: 3.0,
                    ),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
                      child: const Text(
                        '실시간 영상',
                        style: TextStyle(
                          color: Color(0xFF6CA4C8),
                          fontFamily: 'HakgyoansimNadeuri',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 50),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMenuButton(
                icon: Icons.videocam_outlined,
                label: '영상 녹화',
                backgroundColor: const Color(0xFF6CA4C8),
                textColor: Colors.white,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RecordingPage()),
                  );
                },
              ),
              const SizedBox(width: 20),
              _buildMenuButton(
                icon: Icons.settings_outlined,
                label: '설정',
                backgroundColor: Colors.white,
                textColor: const Color(0xFF6CA4C8),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('환경설정'),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: SettingsPage(
                            onScaleChanged: widget.updateTextScale,
                            currentScaleFactor: widget.textScaleFactor,
                          ),
                        ),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('닫기'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMenuButton(
                icon: Icons.bluetooth_searching,
                label: '기기 연결',
                backgroundColor: Colors.white,
                textColor: const Color(0xFF6CA4C8),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ScanScreen()),
                  );
                },
              ),
              const SizedBox(width: 20),
              _buildMenuButton(
                icon: Icons.power_settings_new,
                label: '원격 OFF',
                backgroundColor: const Color(0xFF6CA4C8),
                textColor: Colors.white,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('기기와 연결되어 있지 않습니다.')),
                  );
                },
              ),
            ],
          ),
          const Spacer(flex: 4),
        ],
      ),
    );
  }
}

Widget _buildMenuButton({
  required IconData icon,
  required String label,
  required Color backgroundColor,
  required Color textColor,
  VoidCallback? onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Ink(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: textColor),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );
}

class SpeechBubblePainter extends CustomPainter {
  final Color bubbleColor;
  final Color borderColor;
  final double borderWidth;

  SpeechBubblePainter({
    required this.bubbleColor,
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bubblePath = Path();
    const tailHeight = 12.0;
    final radius = const Radius.circular(16);
    final double inset = borderWidth / 2;
    final Rect rect = Rect.fromLTWH(inset, inset, size.width - (inset * 2), size.height - tailHeight - (inset * 2));

    // A single, continuous path for the bubble and tail.
    bubblePath
      ..moveTo(rect.left + radius.x, rect.top)
      ..lineTo(rect.right - radius.x, rect.top)
      ..arcToPoint(Offset(rect.right, rect.top + radius.y), radius: radius)
      ..lineTo(rect.right, rect.bottom - radius.y)
      ..arcToPoint(Offset(rect.right - radius.x, rect.bottom), radius: radius)
      ..lineTo(size.width * 0.5 + 10, rect.bottom)
      ..lineTo(size.width * 0.5, rect.bottom + tailHeight)
      ..lineTo(size.width * 0.5 - 10, rect.bottom)
      ..lineTo(rect.left + radius.x, rect.bottom)
      ..arcToPoint(Offset(rect.left, rect.bottom - radius.y), radius: radius)
      ..lineTo(rect.left, rect.top + radius.y)
      ..arcToPoint(Offset(rect.left + radius.x, rect.top), radius: radius)
      ..close();

    final shadowPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(bubblePath.shift(const Offset(0, 3)), shadowPaint);

    final bubblePaint = Paint()
      ..color = bubbleColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(bubblePath, bubblePaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawPath(bubblePath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}