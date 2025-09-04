import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_web_socket/dart_frog_web_socket.dart';

// --- 서버 전체에서 공유할 클라이언트 목록 ---
// 클라이언트 ID(String)와 웹소켓 채널(WebSocketChannel)을 저장하는 Map
// 예: {'app-001': channel, 'jetson-001': channel}
final Map<String, WebSocketChannel> clients = {};

// 웹소켓 채널 객체에 클라이언트 ID를 연결(태그)하기 위한 Expando
// 채널이 닫힐 때 어떤 ID를 clients Map에서 제거해야 하는지 알기 위해 사용됩니다.
final Expando<String> clientIds = Expando('clientIds');
// -----------------------------------------

// '/api/ws' 경로로 요청이 오면 이 함수가 실행됩니다.
Future<Response> onRequest(RequestContext context) async {
  final handler = webSocketHandler((channel, protocol) {
    // 처음 연결 시에는 아직 누구인지 모름
    print('A new client connected.');

    // 클라이언트로부터 메시지를 수신 대기합니다.
    channel.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          final type = data['type'] as String?;


          // 메시지 타입에 따라 분기
          switch (type) {
            // 1. 클라이언트 등록 메시지 처리
            case 'register':
              final id = data['id'] as String?;
              if (id != null) {
                clientIds[channel] = id; // 채널에 ID를 연결
                clients[id] = channel;    // 공유 목록에 ID와 채널 저장
                print('✅ Client registered: $id');
              }
              break;

            // 2. WebRTC 시그널링 메시지 처리 (offer, answer, candidate)
            case 'offer':
            case 'answer':
            case 'candidate':
              final senderId = clientIds[channel]; // 메시지 보낸 사람
              final deviceId = data['target'] as String?;
              
              if (senderId != null && deviceId != null) {
                final targetClient = clients[deviceId];
                if (targetClient != null) {
                  final messageToSend = {...data, 'sender': senderId};
                  print("➡️ Forwarding '$type' from $senderId to $deviceId");
                  targetClient.sink.add(jsonEncode(messageToSend));
                  print("dd $deviceId");
                } else {
                  print("❌ Target client '$deviceId' not found or not open.");
                }
              }
              break;
            
            default:
              // 등록이나 시그널링이 아닌 다른 메시지 (기존 코드의 동작)
              final senderId = clientIds[channel];
              print('Message from ${senderId ?? 'unknown'}: $message');
          }
        } catch (e) {
          print('Invalid JSON received or processing error: $e');
        }
      },
      // 연결이 끊어졌을 때 처리
      onDone: () {
        final clientId = clientIds[channel];
        if (clientId != null) {
          clients.remove(clientId); // 공유 목록에서 제거
          print('❌ Client disconnected: $clientId');
        } else {
          print('An unregistered client disconnected.');
        }
      },
      // 에러 처리
      onError: (error) {
        final clientId = clientIds[channel];
        print('Error from client ${clientId ?? 'unknown'}: $error');
      },
    );
  });

  return handler(context);
}

/// '/api/alert' 같은 다른 경로에서 호출하여 현재 접속된 모든 클라이언트에게
/// 비상 알림 메시지를 보내는 함수 (브로드캐스팅)
void sendAlertToAll(String dangerMessage) {
  final alertData = jsonEncode({
    'type': 'DANGER_ALERT',
    'message': dangerMessage,
  });

  // 현재 접속된 모든 클라이언트에게 알림 전송
  // 기존 코드의 'connections' 변수 대신 'clients'를 사용하도록 수정
  for (final channel in clients.values) {
    channel.sink.add(alertData);
  }
  
  print('📢 Sent alert to ${clients.length} clients: $dangerMessage');
}