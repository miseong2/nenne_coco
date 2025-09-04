import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';

// 젯슨 코드에 정의된 것과 동일한 UUID
const String serviceUuid = "A07498CA-AD5B-474E-940D-16F1FBE7E8CD";
const String characteristicUuid = "B07498CA-AD5B-474E-940D-16F1FBE7E8CD";

class WifiSetupScreen extends StatefulWidget {
  final BluetoothDevice device; // 스캔 화면에서 선택된 젯슨 기기
  const WifiSetupScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<WifiSetupScreen> createState() => _WifiSetupScreenState();
}

class _WifiSetupScreenState extends State<WifiSetupScreen> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isConnecting = false;
  bool _isConnected = false;
  Stream<BluetoothConnectionState>
      _connectionStateStream = Stream.empty();

  @override
  void initState() {
    super.initState();
    _connectionStateStream = widget.device.connectionState;
    _connectionStateStream.listen((state) {
      setState(() {
        _isConnected = state == BluetoothConnectionState.connected;
      });
    });
  }

  Future<void> _sendWifiCredentials() async {
    setState(() { _isConnecting = true; });

    try {
      // 1. 젯슨에 연결
      if (!_isConnected) {
        await widget.device.connect();
      }


      // 2. 서비스 탐색
      List<BluetoothService> services = await widget.device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString().toUpperCase() == serviceUuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toUpperCase() == characteristicUuid) {
              // 3. Wi-Fi 정보를 JSON으로 만들어 전송
              final credentials = {
                "ssid": _ssidController.text,
                "password": _passwordController.text,
              };
              final dataToSend = utf8.encode(jsonEncode(credentials));
              
              await characteristic.write(dataToSend);
              
              print("✅ Wi-Fi 정보 전송 성공!");
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("전송 성공! 기기가 10초 후 재부팅됩니다.")),
              );
              await widget.device.disconnect();
              setState(() { _isConnecting = false; });
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              return;
            }
          }
        }
      }
    } catch (e) {
      print("❌ 에러 발생: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("에러 발생: $e")),
      );
      setState(() { _isConnecting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wi-Fi 설정')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _ssidController, decoration: const InputDecoration(labelText: 'Wi-Fi 이름 (SSID)')),
            TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Wi-Fi 비밀번호')),
            const SizedBox(height: 20),
            _isConnecting
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _sendWifiCredentials,
                    child: const Text('젯슨에 Wi-Fi 정보 전송'),
                  ),
          ],
        ),
      ),
    );
  }
}
