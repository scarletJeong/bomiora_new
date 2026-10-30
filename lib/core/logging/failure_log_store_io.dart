import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

const String failureLogFileName = 'bomiora_failure.log';

Future<void> appendFailureLogLine(String line) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}$failureLogFileName');
  await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
  debugPrint('[FailureLog] ${file.path}');
}

Future<String> failureLogDeviceLabel() async {
  return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
}
