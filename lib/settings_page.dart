import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  final Function(double) onScaleChanged;
  final double currentScaleFactor;

  const SettingsPage({
    super.key,
    required this.onScaleChanged,
    required this.currentScaleFactor,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool isLockEnabled = false;
  final TextEditingController _passwordController = TextEditingController();
  late double _currentSliderValue;

  @override
  void initState() {
    super.initState();
    _loadLockState();
    _currentSliderValue = widget.currentScaleFactor;
  }

  Future<void> _loadLockState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isLockEnabled = prefs.getBool('isLocked') ?? false;
    });
  }

  Future<void> _saveLockState(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isLocked', value);
  }

  Future<void> _savePassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    // 'appPassword' 라는 이름으로 비밀번호 문자열(password)을 저장합니다.
    prefs.setString('appPassword', password);
  }

  Future<void> _showPasswordDialog() async {
    _passwordController.clear();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('비밀번호 설정'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('앱을 잠금 설정하려면 비밀번호를 입력하세요.'),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: '비밀번호',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                setState(() { isLockEnabled = false; });
                _saveLockState(false);
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('저장'),
              onPressed: () {
                print('설정된 비밀번호: ${_passwordController.text}');

                _savePassword(_passwordController.text); // 입력된 비밀번호를 저장합니다.

                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        ListTile(
          leading: const Icon(Icons.lock_outline, color: Color(0xFF6CA4C8)),
          title: const Text('앱 잠금'),
          subtitle: const Text('비밀번호나 생체인증으로 앱을 보호합니다.'),
          trailing: Switch(
            value: isLockEnabled,
            onChanged: (value) {
              setState(() {
                isLockEnabled = value;
              });
              _saveLockState(value);
              if (value == true) {
                _showPasswordDialog();
              }
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.text_fields, color: Color(0xFF6CA4C8)),
          title: const Text('글씨 크기 조절'),
          subtitle: Slider(
            value: _currentSliderValue,
            min: 0.8,
            max: 1.5,
            divisions: 7,
            label: '${(_currentSliderValue * 100).round()}%',
            onChanged: (value) {
              setState(() {
                _currentSliderValue = value;
              });
              widget.onScaleChanged(value);
            },
          ),
        ),
      ],
    );
  }
}
