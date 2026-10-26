# Inline flow feasibility prototype

This standalone app exercises additive experimental code exported by
`package:super_text_layout/experimental_flow.dart`. It does not replace the
existing package API or example app.

From this directory:

```sh
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8765
```

Open <http://127.0.0.1:8765/>. Resize the paragraph, toggle the obstacle and region
outlines, drag selections, and click counters before resizing. The stress toggle
uses 10,000 text characters and 100 buttons. The measurement button reports the
current layout duration; it is not a release benchmark.

The palette is an independent canvas participant that wraps between groups of
three swatches. It uses the same range-measurement contract as text and buttons.
See [PROTOCOL.md](PROTOCOL.md) for the short implementation note and review links.

Run the widget tests with:

```sh
flutter test
```

The profile benchmark is captured in a native integration test. To record a
baseline and then enforce its median/p95 limits (from this directory):

```sh
dart run tool/profile_macos.dart --output build/profile/baseline.json
dart run tool/profile_macos.dart --baseline build/profile/baseline.json
```

See [PROFILE_TESTING.md](PROFILE_TESTING.md) for developer/CI instructions,
matching-machine checks, and result export. Current long-run optimization results are in
[LONG_RUN_OPTIMIZATION.md](LONG_RUN_OPTIMIZATION.md). The preceding beginning/middle/end
measurements are in [EDIT_POSITION_BENCHMARK.md](EDIT_POSITION_BENCHMARK.md). The preceding prose
optimizations are in [PROSE_OPTIMIZATIONS.md](PROSE_OPTIMIZATIONS.md). The preceding five changes
are recorded in [SEQUENTIAL_OPTIMIZATIONS.md](SEQUENTIAL_OPTIMIZATIONS.md).

The current backend is horizontal LTR and greedy, with fixed text scaling and no
keyboard editing. The range-measurement protocol is experimental, and text break
discovery uses pinned Unicode 16 rules with Flutter dictionary tailoring. See
[Unicode coverage and tailoring](../tool/unicode/README.md) for the precise scope. Basic accessibility checks do not
constitute full screen-reader validation.

See the [protocol proposal](../doc/design/inline_fragmentation_protocol.md) for
agreed requirements, demonstrated behavior, limitations, and the proposed next
refactor. Keep the existing blank-line layout when making selection fixes.

The prose/test font is Roboto, copied from the Flutter SDK's material fonts, with
its license in [assets/fonts/LICENSE.txt](assets/fonts/LICENSE.txt). Inline code
uses Fira Mono from the repository's Quill clone example, with its license in
[assets/fonts/FiraMono-OFL.txt](assets/fonts/FiraMono-OFL.txt). Both are bundled in
the standalone demo; the layout library adds no font or native dependencies.
