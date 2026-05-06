import 'package:get/get.dart';

class DebugLogEntry {
  DebugLogEntry({
    required this.scope,
    required this.message,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  final DateTime time;
  final String scope;
  final String message;
}

class DebugLogService extends GetxService {
  DebugLogService({this.maxEntries = 120});

  final int maxEntries;
  final RxList<DebugLogEntry> entries = <DebugLogEntry>[].obs;

  void log(String scope, String message) {
    entries.insert(
      0,
      DebugLogEntry(scope: scope, message: message),
    );
    if (entries.length > maxEntries) {
      entries.removeRange(maxEntries, entries.length);
    }
  }

  void clear() {
    entries.clear();
  }
}
