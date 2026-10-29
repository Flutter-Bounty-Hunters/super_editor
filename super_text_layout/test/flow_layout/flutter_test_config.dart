import 'dart:async';

// Flow tests load their own fonts and also run in Chrome. Keep them independent
// of the package's golden-test configuration and its platform-specific helpers.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await testMain();
}
