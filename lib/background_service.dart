import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const String websocketUrl = "wss://infantserver-1073747594853.asia-northeast3.run.app/api/ws";

// 1. 백그라운드에서 실행될 진입점 함수
 @pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  // 2. 서버와 웹소켓 연결 및 메시지 수신 대기
  WebSocketChannel? channel;
  Timer? reconnectTimer;

  void connect() {
    try {
      channel = WebSocketChannel.connect(Uri.parse(websocketUrl));
      print("✅ [Background] WebSocket Connected!");

      // 연결 성공 직후 register 메시지 전송
      final registrationMessage = {
        "type": "register",
        "id": "app-001" // 앱의 고유 ID
      };
      channel!.sink.add(json.encode(registrationMessage));
      print('[Background] Sent registration message for app-001');

      channel!.stream.listen((message) {
        final data = json.decode(message);
        if (data['type'] == 'DANGER_ALERT') {
          String alertMessage = data['message'];
          print("🚨 [Background] DANGER_ALERT Received: $alertMessage");
          // 3. 알림 메시지 수신 시 로컬 알림 표시
          showNotification(flutterLocalNotificationsPlugin, alertMessage);
        }
      }, onDone: () {
        print("🔌 [Background] WebSocket disconnected. Reconnecting...");
        reconnectTimer = Timer(const Duration(seconds: 5), connect);
      }, onError: (error) {
        print("❌ [Background] WebSocket error: $error. Reconnecting...");
        reconnectTimer = Timer(const Duration(seconds: 5), connect);
      });
    } catch (e) {
      print("❌ [Background] WebSocket connection failed: $e. Reconnecting...");
      reconnectTimer = Timer(const Duration(seconds: 5), connect);
    }
  }

  connect(); // 최초 연결 시도

  service.on('stopService').listen((event) {
    reconnectTimer?.cancel();
    channel?.sink.close();
    service.stopSelf();
  });
}

// 4. 로컬 알림을 화면에 표시하는 함수
void showNotification(FlutterLocalNotificationsPlugin plugin, String message) async {
  final AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails('danger_alert_channel', '위험 감지 알림',
          channelDescription: '영유아 위험 상황을 알립니다.',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: false,
          styleInformation: BigTextStyleInformation(
            message,
            contentTitle: '🚨 위험 감지!',
            htmlFormatContentTitle: true,
            htmlFormatBigText: true,
          ),
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        );
  final NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);
  await plugin.show(0, '🚨 위험 감지!', message, platformChannelSpecifics,
      payload: 'danger_alert');
}

// 5. 백그라운드 서비스 초기화 함수
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'danger_alert_channel', // ID
    '위험 감지 알림', // Title
    description: '영유아 위험 상황을 알립니다.', // Description
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'danger_alert_channel',
      initialNotificationTitle: '낸내코코',
      initialNotificationContent: '모니터링 서비스가 실행 중입니다.',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
    ),
  );
}