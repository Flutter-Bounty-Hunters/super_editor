import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// SDK-only VM-service collector. First argument is the Flutter run log, second
/// is the output JSON path. Attach only to the opt-in warmed benchmark build.
Future<void> main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError('Usage: capture_cpu_profile.dart RUN_LOG OUTPUT_JSON');
  }
  final log = File(args[0]);
  final deadline = DateTime.now().add(const Duration(minutes: 5));
  Uri? uri;
  while (DateTime.now().isBefore(deadline)) {
    final text = log.existsSync() ? log.readAsStringSync() : '';
    if (text.contains('Encountered disallowed Dart VM flag') ||
        text.contains('Error running application')) {
      throw StateError('The profile app failed to start; inspect ${log.path}');
    }
    final match =
        RegExp(r'A Dart VM Service on macOS is available at: (http://\S+)')
            .firstMatch(text);
    if (match != null) {
      final http = Uri.parse(match.group(1)!);
      uri = http.replace(scheme: 'ws', path: '${http.path}ws');
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  if (uri == null) {
    throw StateError('No VM-service URL appeared in ${log.path}');
  }
  final rpc = await _Rpc.connect(uri);
  try {
    final vm = await rpc.call('getVM');
    final isolates = vm['isolates'] as List<dynamic>;
    final isolate = isolates.firstWhere((dynamic i) => i['name'] == 'main')
        as Map<String, dynamic>;
    final id = isolate['id'] as String;
    Map<String, dynamic>? status;
    while (DateTime.now().isBefore(deadline)) {
      final state = await rpc.call('getIsolate', {'isolateId': id});
      if ((state['extensionRPCs'] as List<dynamic>)
          .contains('ext.flowBenchmark.status')) {
        status = await rpc.call('ext.flowBenchmark.status', {'isolateId': id});
        if (status['ready'] == true) break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (status?['ready'] != true) {
      throw StateError('Benchmark did not become ready');
    }
    final flags = await rpc.call('getFlagList');
    await rpc.call('clearCpuSamples', {'isolateId': id});
    final start = (await rpc.call('getVMTimelineMicros'))['timestamp'] as int;
    await rpc.call('ext.flowBenchmark.start', {'isolateId': id});
    // ignore: avoid_print
    print('Sampling warmed profile benchmark...');
    while (DateTime.now().isBefore(deadline)) {
      status = await rpc.call('ext.flowBenchmark.status', {'isolateId': id});
      if (status['done'] == true) break;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (status?['done'] != true) throw StateError('Benchmark did not finish');
    final end = (await rpc.call('getVMTimelineMicros'))['timestamp'] as int;
    final cpu = await rpc.call('getCpuSamples', {
      'isolateId': id,
      'timeOriginMicros': start,
      'timeExtentMicros': end - start,
    });
    final output = File(args[1]);
    await output.parent.create(recursive: true);
    await output.writeAsString(jsonEncode({
      'captureStartMicros': start,
      'captureEndMicros': end,
      'vmVersion': vm['version'],
      'profilerFlags': (flags['flags'] as List<dynamic>)
          .where((dynamic flag) =>
              RegExp('profil|sample').hasMatch(flag['name'] as String))
          .toList(),
      'benchmark': status!['result'],
      'cpu': cpu,
    }));
    final tags = <String, int>{};
    for (final dynamic sample in cpu['samples'] as List<dynamic>) {
      final tag = sample['userTag'] as String? ?? 'Default';
      tags.update(tag, (v) => v + 1, ifAbsent: () => 1);
    }
    // ignore: avoid_print
    print(
        'Saved ${output.path}: ${cpu['sampleCount']} samples, period ${cpu['samplePeriod']} us; tags=$tags');
  } finally {
    await rpc.close();
  }
}

class _Rpc {
  _Rpc(this.socket) {
    socket.listen((dynamic event) {
      final message = jsonDecode(event as String) as Map<String, dynamic>;
      final id = message['id'] as String?;
      if (id == null) return;
      final pending = _pending.remove(id);
      if (pending == null) return;
      if (message.containsKey('error')) {
        pending.completeError(StateError('${message['error']}'));
      } else {
        pending.complete(message['result'] as Map<String, dynamic>);
      }
    });
  }
  final WebSocket socket;
  final _pending = <String, Completer<Map<String, dynamic>>>{};
  int _next = 0;
  static Future<_Rpc> connect(Uri uri) async =>
      _Rpc(await WebSocket.connect(uri.toString()));
  Future<Map<String, dynamic>> call(String method,
      [Map<String, dynamic> params = const {}]) {
    final id = '${++_next}';
    final future = Completer<Map<String, dynamic>>();
    _pending[id] = future;
    socket.add(jsonEncode(
        {'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params}));
    return future.future.timeout(const Duration(seconds: 30));
  }

  Future<void> close() async {
    await socket.close();
  }
}
