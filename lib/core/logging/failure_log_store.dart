import 'failure_log_store_stub.dart'
    if (dart.library.html) 'failure_log_store_web.dart'
    if (dart.library.io) 'failure_log_store_io.dart' as failure_log_store;

Future<void> appendFailureLogLine(String line) =>
    failure_log_store.appendFailureLogLine(line);

Future<String> failureLogDeviceLabel() =>
    failure_log_store.failureLogDeviceLabel();
