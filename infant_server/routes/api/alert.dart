import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
//import '../ws.dart'; // ws.dart 파일의 함수를 가져옴
import 'ws.dart'; // ✅ 같은 폴더면 이렇게

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }
  final json = await context.request.json() as Map<String, dynamic>;
  final dangerType = json['danger'] as String?;

  if (dangerType != null) {
    print('🚨 DANGER ALERT received: $dangerType');
    // 웹소켓에 연결된 모든 클라이언트에게 알림 전송
    sendAlertToAll('위험 감지: $dangerType');
  }
  return Response.json(body: {'status': 'alert processed'});
}