import 'package:flutter/services.dart';

/// SmsService — bridges Flutter to the native Android SMS MethodChannel & EventChannel.
class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  static const MethodChannel _methodChannel = MethodChannel('upi_lens/sms');
  static const EventChannel _eventChannel = EventChannel('upi_lens/sms_stream');

  /// Fetch all UPI SMS from the last 90 days via MethodChannel.
  Future<List<Map<String, String>>> getSmsHistory() async {
    try {
      final List<dynamic> result =
          await _methodChannel.invokeMethod('getSmsHistory');
      return result
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
    } on PlatformException catch (e) {
      // Return empty list if permission denied or other platform error
      print('SmsService.getSmsHistory error: ${e.message}');
      return [];
    }
  }

  /// Stream of live incoming UPI SMS via EventChannel.
  Stream<Map<String, String>> get liveSmStream {
    return _eventChannel.receiveBroadcastStream().map(
      (event) => Map<String, String>.from(event as Map),
    );
  }
}
