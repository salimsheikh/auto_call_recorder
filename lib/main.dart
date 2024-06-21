import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:telephony/telephony.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: CallRecorder(),
    );
  }
}

class CallRecorder extends StatefulWidget {
  const CallRecorder({Key? key}) : super(key: key);

  @override
  _CallRecorderState createState() => _CallRecorderState();
}

class _CallRecorderState extends State<CallRecorder> {
  final Record _record =
      Record(); // Ensure this is the correct usage of Record class
  final Telephony _telephony = Telephony.instance;
  Directory? _appDir;
  String? _filePath;
  String? _currentNumber;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initDir();
    _listenToCalls();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.microphone,
      Permission.storage,
      Permission.phone,
    ].request();
  }

  Future<void> _initDir() async {
    _appDir = await getApplicationDocumentsDirectory();
  }

  void _listenToCalls() {
    _telephony.listenIncomingCall(
      onNewIncomingCall: (PhoneCall call) {
        if (call.state == PhoneCallState.callIncoming) {
          _currentNumber = call.phoneNumber;
          _startRecording();
        } else if (call.state == PhoneCallState.callEnded) {
          _stopRecording();
        }
      },
      listenInBackground: false,
    );
  }

  Future<void> _startRecording() async {
    if (await _record.hasPermission()) {
      final filePath =
          '${_appDir!.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      setState(() {
        _filePath = filePath;
      });
      await _record.start(
        path: filePath,
        encoder: AudioEncoder.AAC,
        bitRate: 128000,
        samplingRate: 44100,
      );
    }
  }

  Future<void> _stopRecording() async {
    if (await _record.isRecording()) {
      await _record.stop();
      _sendEmail();
    }
  }

  Future<void> _sendEmail() async {
    if (_filePath != null && _currentNumber != null) {
      final Email email = Email(
        body: 'Call recording from number: $_currentNumber',
        subject: 'Call Recording - $_currentNumber',
        recipients: ['example@example.com'],
        attachmentPaths: [_filePath!],
        isHTML: false,
      );

      await FlutterEmailSender.send(email);
      File(_filePath!).delete();
      setState(() {
        _filePath = null;
        _currentNumber = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Call Recorder')),
      body: const Center(
        child: Text('Listening for calls...'),
      ),
    );
  }
}
