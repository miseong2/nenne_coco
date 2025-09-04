import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LockScreen extends StatefulWidget {
  // 잠금 해제에 성공했을 때, 어떤 행동을 할지 부모에게 전달받을 함수
  final VoidCallback onUnlock;

  const LockScreen({super.key, required this.onUnlock});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _checkPassword() async {
    final prefs = await SharedPreferences.getInstance();
    // 저장된 비밀번호를 불러옵니다. 없으면 빈 문자열을 사용합니다.
    final savedPassword = prefs.getString('appPassword') ?? '';

    // 현재 입력한 비밀번호와 저장된 비밀번호가 일치하는지 확인합니다.
    if (_passwordController.text == savedPassword) {
      // 일치하면, 부모에게 전달받은 onUnlock 함수를 실행합니다! (잠금 해제!)
      widget.onUnlock();
    } else {
      // 일치하지 않으면, 사용자에게 "틀렸습니다" 라는 메시지를 보여줍니다.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.grey),
              const SizedBox(height: 24),
              const Text('앱이 잠겨 있습니다', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: '비밀번호를 입력하세요',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _checkPassword, // 버튼을 누르면 비밀번호 확인 함수 실행
                child: const Text('잠금 해제'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}