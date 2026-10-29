# Super Text Layout examples

The example app demonstrates the existing SuperText widgets and flow-based layout.
From this directory, install dependencies with `flutter pub get`.

Run the existing SuperText examples:

```sh
flutter run -t lib/main.dart
```

Run the flow-layout example directly:

```sh
flutter run -t lib/main_flow_layout.dart
```

For a browser demo:

```sh
flutter run -d web-server -t lib/main_flow_layout.dart --web-hostname 127.0.0.1 --web-port 8765
```

The flow example includes wrapping inline decorations, real Flutter widgets,
custom fragmentable content, changing widths, obstacles, and externally painted
selections. Its implementation is in `lib/flow_layout/` and uses
`package:super_text_layout/experimental_flow.dart` from the package.

Run example UI tests here with `flutter test`. Engine correctness tests live in
the package’s `test/flow_layout/`; run those from the package root with
`flutter test test/flow_layout`.

The sibling [performance project](../performance/README.md) owns benchmark tests,
profile runners, CPU capture tools, exploratory studies, fixtures, and recorded
results. See the [flow-layout guide](doc/flow_layout/README.md) and
[measurement protocol](doc/flow_layout/PROTOCOL.md) for the example and engine.
