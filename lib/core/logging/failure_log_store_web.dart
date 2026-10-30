import 'dart:html' as html;

import 'package:flutter/foundation.dart';

const String _storageKey = 'bomiora_failure.log';
const int _maxChars = 400000;

Future<void> appendFailureLogLine(String line) async {
  final storage = html.window.localStorage;
  final prev = storage[_storageKey] ?? '';
  var next = prev.isEmpty ? '$line\n' : '$prev$line\n';
  if (next.length > _maxChars) {
    next = next.substring(next.length - _maxChars);
    final cut = next.indexOf('\n');
    if (cut >= 0 && cut < next.length - 1) {
      next = next.substring(cut + 1);
    }
  }
  storage[_storageKey] = next;
  debugPrint('[FailureLog] web localStorage key=$_storageKey');
}

Future<String> failureLogDeviceLabel() async {
  return html.window.navigator.userAgent;
}
