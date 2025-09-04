import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  final _renderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  bool _isConnected = false;
  String _status = '초기화 중...';

  // WebSocket 서버 주소
  final String _websocketUrl = "wss://infantserver-1073747594853.asia-northeast3.run.app/api/ws";
  // Jetson 보드의 고유 ID
  final String _jetsonId = "jetson-001";
  // --- [수정] 앱 자신의 고유 ID를 상수로 관리 ---
  final String _appId = "app-001";

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _renderer.initialize();
    _connect();
  }

  Future<void> _connect() async {
    setState(() {
      _status = '서버에 연결 중...';
    });

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_websocketUrl));

      final registrationMessage = {"type": "register", "id": _appId};
      _channel!.sink.add(json.encode(registrationMessage));
      print('Sent registration message for $_appId');

      setState(() {
        _status = '서버 연결 성공. 영상 신호 대기 중...';
      });

      _channelSubscription = _channel!.stream.listen(
            (message) async {
          final data = json.decode(message);
          final type = data['type'];
          print('Received message: $data');

          // 젯슨이 보낸 메시지의 targetId가 나(앱)의 ID와 일치하는지 확인
          if (type == 'answer' && data['deviceId'] == _appId) {
            final sdp = data['sdp'];
            await _peerConnection?.setRemoteDescription(
              RTCSessionDescription(sdp, type),
            );
          } else if (type == 'candidate' && data['deviceId'] == _appId) {
            final candidate = data['candidate'];
            await _peerConnection?.addCandidate(
              RTCIceCandidate(
                candidate['candidate'],
                candidate['sdpMid'],
                candidate['sdpMLineIndex'],
              ),
            );
          }
        },
        onDone: () {
          print('WebSocket disconnected.');
          if (mounted) {
            setState(() {
              _status = '서버 연결 끊김.';
              _isConnected = false;
            });
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          if (mounted) {
            setState(() {
              _status = '서버 연결 오류.';
              _isConnected = false;
            });
          }
        },
      );

      await _createPeerConnection();
      await _createAndSendOffer();

    } catch (e) {
      print('Connection error: $e');
      if (mounted) {
        setState(() {
          _status = '연결 실패: $e';
        });
      }
    }
  }

  Future<void> _createPeerConnection() async {
    setState(() {
      _status = 'WebRTC 연결 설정 중...';
    });

    final Map<String, dynamic> configuration = {
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
        {'url': 'stun:stun1.l.google.com:19302'},
      ]
    };

    _peerConnection = await createPeerConnection(configuration);

    _peerConnection!.onTrack = (event) {
      print("Remote track received: ${event.track.kind}");
      if (event.track.kind == 'video' && event.streams.isNotEmpty) {
        if (mounted) {
          setState(() {
            _renderer.srcObject = event.streams[0];
          });
        }
      }
    };

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate != null) {
        _sendToServer({
          'type': 'candidate',
          'deviceId': _jetsonId, // 'deviceId' -> 'targetId'로 통일
          'senderId': _appId,   // 누가 보냈는지 명시
          'candidate': {
            'sdpMLineIndex': candidate.sdpMLineIndex,
            'sdpMid': candidate.sdpMid,
            'candidate': candidate.candidate,
          },
        });
      }
    };

    _peerConnection!.onIceConnectionState = (state) {
      print('ICE Connection State: $state');
      if (mounted) {
        setState(() {
          if (state == RTCIceConnectionState.RTCIceConnectionStateConnected || state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
            _status = '영상 연결 성공';
            _isConnected = true;
          } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
              state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
            _status = '영상 연결 실패 또는 끊김';
            _isConnected = false;
          }
        });
      }
    };
  }

  Future<void> _createAndSendOffer() async {
    setState(() {
      _status = 'Jetson에 영상 연결 요청 중...';
    });
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    _sendToServer({
      'type': 'offer',
      'deviceId': _jetsonId, // 'deviceId' -> 'targetId'로 통일
      'senderId': _appId,   // 누가 보냈는지 명시
      'sdp': offer.sdp,
    });
  }

  void _sendToServer(Map<String, dynamic> data) {
    if (_channel != null) {
      final messageString = json.encode(data);

      // --- !!! 이 로그를 추가해주세요 !!! ---
      print('>>> SENDING TO SERVER: $messageString');

      _channel!.sink.add(messageString);
    } else {
      print('!!! ERROR: WebSocket channel is null. Cannot send message.');
    }
  }

  @override
  void dispose() {
    _renderer.dispose();
    _peerConnection?.dispose();
    _channelSubscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('실시간 영상'),
      ),
      body: Center(
        child: _isConnected
            ? RTCVideoView(_renderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(_status, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
