import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
// import 'package:flutter_vlc_player/flutter_vlc_player.dart'; // WebRTC로 전환되어 비활성화
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_picker_spinner/time_picker_spinner.dart';
import 'package:share_plus/share_plus.dart';

// 예약 정보를 관리하는 클래스
class RecordingSchedule {
  final String id;
  TimeOfDay startTime;
  TimeOfDay endTime;

  RecordingSchedule({required this.id, required this.startTime, required this.endTime});

  factory RecordingSchedule.fromJson(Map<String, dynamic> json) {
    return RecordingSchedule(
      id: json['id'],
      startTime: TimeOfDay(hour: json['start_hour'], minute: json['start_minute']),
      endTime: TimeOfDay(hour: json['end_hour'], minute: json['end_minute']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'start_hour': startTime.hour,
      'start_minute': startTime.minute,
      'end_hour': endTime.hour,
      'end_minute': endTime.minute,
    };
  }
}

class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  // late VlcPlayerController _vlcController; // WebRTC로 전환되어 비활성화
  bool _isRecording = false;
  // bool _isPlaying = false; // WebRTC로 전환되어 비활성화
  List<FileSystemEntity> _savedFiles = [];
  late Directory _recordingDir;

  final Map<String, List<Timer>> _activeTimers = {};

  @override
  void initState() {
    super.initState();
    /* // WebRTC로 전환되어 비활성화
    _vlcController = VlcPlayerController.network(
      "rtsp://192.168.0.30:8554/stream",
      hwAcc: HwAcc.full,
      autoPlay: false,
      options: VlcPlayerOptions(),
    );
    */
    _initFileSystem();
    _rescheduleAll();
  }

  Future<void> _initFileSystem() async {
    final appDir = await getApplicationDocumentsDirectory();
    _recordingDir = Directory('${appDir.path}/recordings');
    if (!await _recordingDir.exists()) {
      await _recordingDir.create(recursive: true);
    }
    await _deleteOldFiles();
    await _loadSavedFiles();
  }

  Future<void> _loadSavedFiles() async {
    if (!await _recordingDir.exists()) return;
    final files = (await _recordingDir.list().toList()).where((f) => f.path.endsWith('.mp4')).toList();
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    if (mounted) setState(() => _savedFiles = files);
  }

  Future<void> _deleteOldFiles() async {
    if (!await _recordingDir.exists()) return;
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final files = await _recordingDir.list().toList();
    for (var file in files) {
      if ((await file.stat()).modified.isBefore(sevenDaysAgo)) {
        await file.delete();
      }
    }
  }

  void _toggleRecording() async {
    // WebRTC 스트리밍 방식으로 인해 실제 녹화는 비활성화 상태임을 알립니다.
    // 대신 테스트용으로 가짜 영상 파일을 생성합니다.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('안드로이드 스튜디오에서 녹화 파일 저장 기능을 보여주기 위한 테스트 파일을 생성합니다.')),
    );

    // 가짜 영상 파일 생성 로직
    final fileName = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final filePath = '${_recordingDir.path}/$fileName.mp4';
    final file = File(filePath);
    await file.writeAsString('This is a test video file for sharing.');
    await _loadSavedFiles(); // 파일 목록 새로고침
  }

  Future<List<RecordingSchedule>> _loadSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('schedules_list');
    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        return jsonList.map((json) => RecordingSchedule.fromJson(json)).toList();
      } catch (e) {
        print("Error decoding schedules: $e");
        return [];
      }
    }
    return [];
  }

  Future<void> _saveSchedules(List<RecordingSchedule> schedules) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(schedules.map((s) => s.toJson()).toList());
    await prefs.setString('schedules_list', jsonString);
  }

  Future<void> _rescheduleAll() async {
    _activeTimers.forEach((_, timers) => timers.forEach((t) => t.cancel()));
    _activeTimers.clear();

    final schedules = await _loadSchedules();
    final now = DateTime.now();

    for (var schedule in schedules) {
      var startDateTime = DateTime(now.year, now.month, now.day, schedule.startTime.hour, schedule.startTime.minute);
      var endDateTime = DateTime(now.year, now.month, now.day, schedule.endTime.hour, schedule.endTime.minute);

      if (endDateTime.isBefore(startDateTime) || endDateTime.isAtSameMomentAs(startDateTime)) {
        endDateTime = endDateTime.add(const Duration(days: 1));
      }
      if (startDateTime.isBefore(now)) {
        startDateTime = startDateTime.add(const Duration(days: 1));
        endDateTime = endDateTime.add(const Duration(days: 1));
      }

      final startDelay = startDateTime.difference(now);
      if (startDelay.isNegative) continue;

      final startTimer = Timer(startDelay, _toggleRecording);
      final recordingDuration = endDateTime.difference(startDateTime);
      final stopTimer = Timer(startDelay + recordingDuration, _toggleRecording);
      
      _activeTimers[schedule.id] = [startTimer, stopTimer];
    }
  }

  String _formatTime(BuildContext context, TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    final format = DateFormat.jm();
    return format.format(dt);
  }

  void _showAddOrEditScheduleDialog({RecordingSchedule? existingSchedule}) {
    /* // WebRTC로 전환되어 비활성화
    final wasPlaying = _isPlaying;
    if (wasPlaying) {
      _vlcController.pause();
      setState(() {
        _isPlaying = false;
      });
    }
    */

    final now = DateTime.now();
    DateTime startTime = existingSchedule != null
        ? DateTime(now.year, now.month, now.day, existingSchedule.startTime.hour, existingSchedule.startTime.minute)
        : now;
    DateTime endTime = existingSchedule != null
        ? DateTime(now.year, now.month, now.day, existingSchedule.endTime.hour, existingSchedule.endTime.minute)
        : now.add(const Duration(hours: 1));
    
    final isEditing = existingSchedule != null;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEditing ? '예약 수정' : '녹화 시간 예약', style: const TextStyle(fontSize: 18)),
              contentPadding: const EdgeInsets.only(top: 20.0, left: 16.0, right: 16.0),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text('시작 시간', style: TextStyle(fontSize: 14)),
                          const Spacer(),
                          TimePickerSpinner(
                            is24HourMode: false,
                            time: startTime,
                            normalTextStyle: const TextStyle(fontSize: 16, color: Colors.grey),
                            highlightedTextStyle: const TextStyle(fontSize: 20, color: Colors.black),
                            spacing: 20,
                            itemHeight: 40,
                            isForce2Digits: true,
                            onTimeChange: (time) {
                              setState(() {
                                startTime = time;
                                errorMessage = null;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('종료 시간', style: TextStyle(fontSize: 14)),
                          const Spacer(),
                          TimePickerSpinner(
                            is24HourMode: false,
                            time: endTime,
                            normalTextStyle: const TextStyle(fontSize: 16, color: Colors.grey),
                            highlightedTextStyle: const TextStyle(fontSize: 20, color: Colors.black),
                            spacing: 20,
                            itemHeight: 40,
                            isForce2Digits: true,
                            onTimeChange: (time) {
                              setState(() {
                                endTime = time;
                                errorMessage = null;
                              });
                            },
                          ),
                        ],
                      ),
                      if (errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newStartTime = TimeOfDay.fromDateTime(startTime);
                    final newEndTime = TimeOfDay.fromDateTime(endTime);

                    final schedules = await _loadSchedules();

                    bool isOverlapping = false;
                    for (var schedule in schedules) {
                      if (isEditing && schedule.id == existingSchedule!.id) {
                        continue;
                      }

                      final existingStart = DateTime(0, 0, 0, schedule.startTime.hour, schedule.startTime.minute);
                      final existingEnd = DateTime(0, 0, 0, schedule.endTime.hour, schedule.endTime.minute);
                      final newStart = DateTime(0, 0, 0, newStartTime.hour, newStartTime.minute);
                      final newEnd = DateTime(0, 0, 0, newEndTime.hour, newEndTime.minute);

                      if (newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart)) {
                        isOverlapping = true;
                        break;
                      }
                    }

                    if (isOverlapping) {
                      setState(() {
                        errorMessage = '이미 예약된 시간입니다.';
                      });
                      return;
                    }

                    if (isEditing) {
                      final index = schedules.indexWhere((s) => s.id == existingSchedule!.id);
                      if (index != -1) {
                        schedules[index].startTime = newStartTime;
                        schedules[index].endTime = newEndTime;
                      }
                    } else {
                      final newId = DateTime.now().millisecondsSinceEpoch.toString();
                      schedules.add(RecordingSchedule(id: newId, startTime: newStartTime, endTime: newEndTime));
                    }

                    await _saveSchedules(schedules);
                    await _rescheduleAll();
                    
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEditing ? '예약이 수정되었습니다.' : '새로운 예약이 추가되었습니다.')),
                    );
                  },
                  child: Text(isEditing ? '수정' : '예약'),
                ),
              ],
            );
          },
        );
      },
    )/* // WebRTC로 전환되어 비활성화
    .then((_) {
      if (wasPlaying) {
        _vlcController.play();
        setState(() {
          _isPlaying = true;
        });
      }
    })*/;
  }

  void _showScheduledTimesDialog() {
    /* // WebRTC로 전환되어 비활성화
    final wasPlaying = _isPlaying;
    if (wasPlaying) {
      _vlcController.pause();
      setState(() {
        _isPlaying = false;
      });
    }
    */

    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<List<RecordingSchedule>>(
          future: _loadSchedules(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            
            final schedules = snapshot.data!;
            schedules.sort((a, b) {
              final aDateTime = DateTime(0, 0, 0, a.startTime.hour, a.startTime.minute);
              final bDateTime = DateTime(0, 0, 0, b.startTime.hour, b.startTime.minute);
              return aDateTime.compareTo(bDateTime);
            });

            return AlertDialog(
              title: const Text('설정된 예약 시간', style: TextStyle(fontSize: 18)),
              contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              content: SizedBox(
                width: double.maxFinite,
                child: schedules.isEmpty
                    ? const Text('설정된 예약이 없습니다.', style: TextStyle(fontSize: 14))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: schedules.length,
                        itemBuilder: (context, index) {
                          final schedule = schedules[index];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: const Color(0xFF6CA4C8),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_formatTime(context, schedule.startTime)} - ${_formatTime(context, schedule.endTime)}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              IconButton(
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _showAddOrEditScheduleDialog(existingSchedule: schedule);
                                },
                              ),
                              IconButton(
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                onPressed: () async {
                                  final currentSchedules = await _loadSchedules();
                                  currentSchedules.removeWhere((s) => s.id == schedule.id);
                                  await _saveSchedules(currentSchedules);
                                  await _rescheduleAll();
                                  Navigator.of(context).pop();
                                  _showScheduledTimesDialog();
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('예약이 삭제되었습니다.')));
                                },
                              ),
                            ],
                          );
                        },
                      ),
              ),
              actions: [ TextButton(child: const Text('닫기'), onPressed: () => Navigator.of(context).pop()) ],
            );
          },
        );
      },
    )/* // WebRTC로 전환되어 비활성화
    .then((_) {
      if (wasPlaying) {
        _vlcController.play();
        setState(() {
          _isPlaying = true;
        });
      }
    })*/;
  }

  @override
  void dispose() {
    // _vlcController.dispose(); // WebRTC로 전환되어 비활성화
    _activeTimers.forEach((_, timers) => timers.forEach((t) => t.cancel()));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('영상 녹화')),
      body: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black,
                ),
              ),
              /* // WebRTC로 전환되어 비활성화
              VlcPlayer(
                controller: _vlcController,
                aspectRatio: 16 / 9,
                placeholder: const Center(child: CircularProgressIndicator()),
              ),
              if (!_isPlaying)
                IconButton(
                  icon: const Icon(Icons.play_arrow, color: Colors.white, size: 64),
                  onPressed: () {
                    _vlcController.play();
                    setState(() {
                      _isPlaying = true;
                    });
                  },
                ),
              */
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _toggleRecording,
                  icon: Icon(_isRecording ? Icons.stop : Icons.circle),
                  label: Text(_isRecording ? '녹화 종료' : '녹화 시작'),
                  style: ElevatedButton.styleFrom(backgroundColor: _isRecording ? Colors.red : Colors.green, foregroundColor: Colors.white),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => _showAddOrEditScheduleDialog(),
                      child: const Text('녹화 시간 예약'),
                    ),
                    ElevatedButton(
                      onPressed: _showScheduledTimesDialog,
                      child: const Text('예약된 시간'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('저장된 영상', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _savedFiles.isEmpty
                ? const Center(child: Text('저장된 영상이 없습니다.'))
                : ListView.builder(
                    itemCount: _savedFiles.length,
                    itemBuilder: (context, index) {
                      final file = _savedFiles[index];
                      return ListTile(
                        leading: const Icon(Icons.movie),
                        title: Text(file.path.split('/').last),
                        subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(file.statSync().modified)),
                        onTap: () => _shareVideo(file),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _deleteFile(file),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFile(FileSystemEntity file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('파일 삭제'),
        content: Text('\'${file.path.split('/').last}\' 파일을 정말로 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await file.delete();
        await _loadSavedFiles(); // 목록 새로고침
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('파일이 삭제되었습니다.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일 삭제 중 오류 발생: $e')),
        );
      }
    }
  }

  Future<void> _shareVideo(FileSystemEntity file) async {
    if (file is! File) return;
    try {
      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: '녹화된 영상 파일');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('파일 공유 중 오류 발생: $e')),
      );
    }
  }
}
