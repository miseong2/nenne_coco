import 'dart:async';
import 'package:nenne_coco/wifi_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  String _scanMessage = '돋보기 아이콘을 눌러 스캔을 시작하세요.';
  late StreamSubscription<List<ScanResult>> _scanSubscription;
  late StreamSubscription<bool> _isScanningSubscription;

  @override
  void initState() {
    super.initState();

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      // Re-enable the filter to show only devices with a platform name.
      _scanResults = results;
      if (mounted) {
        setState(() {});
      }
    }, onError: (e) {
      print("Scan Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('스캔 오류: $e')),
        );
      }
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      _isScanning = state;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _scanSubscription.cancel();
    _isScanningSubscription.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    print("Starting scan...");
    setState(() {
      _scanMessage = '';
      _scanResults = [];
    });

    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('블루투스를 활성화해주세요.')),
        );
      }
      print("Scan failed: Bluetooth is off.");
      setState(() {
         _scanMessage = '블루투스를 활성화한 후 다시 시도해주세요.';
      });
      return;
    }

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
      await Future.delayed(const Duration(seconds: 5));
      print("Scan finished.");
      if (_scanResults.isEmpty && mounted) {
        setState(() {
          _scanMessage = '주변에 연결 가능한 기기가 없습니다.\n다시 시도해주세요.';
        });
      }
    } catch (e) {
      print("Start Scan Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('스캔 시작 오류: $e')),
        );
        setState(() {
          _scanMessage = '스캔 중 오류가 발생했습니다.';
        });
      }
    }
  }

  void _connectToDevice(BluetoothDevice device) {
    FlutterBluePlus.stopScan();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WifiSetupScreen(device: device),
      ),
    );
  }

  Widget _buildBody() {
    if (_isScanning && _scanResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('주변 기기를 검색 중입니다...', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    if (_scanResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            _scanMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[700], height: 1.5),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _startScan,
      child: ListView.builder(
        itemCount: _scanResults.length,
        itemBuilder: (context, index) {
          final result = _scanResults[index];
          return ListTile(
            title: Text(result.device.platformName.isNotEmpty ? result.device.platformName : '이름 없는 기기'),
            subtitle: Text(result.device.remoteId.toString()),
            trailing: ElevatedButton(
              child: const Text('연결'),
              onPressed: () => _connectToDevice(result.device),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('기기 검색'),
        actions: [          _isScanning
              ? const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white))))
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _startScan,
                )
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _startScan,
        tooltip: '스캔 시작',
        child: Icon(_isScanning ? Icons.stop : Icons.search),
      ),
    );
  }
}