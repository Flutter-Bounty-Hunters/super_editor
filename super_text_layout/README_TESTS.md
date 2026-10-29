# Running tests

In order to run the golden tests, Docker must be installed. See docs for installing Docker Desktop:
- macOS: https://docs.docker.com/desktop/install/mac-install/
- Linux: https://docs.docker.com/desktop/install/linux-install/
- Windows: https://docs.docker.com/desktop/install/windows-install/

Activate the golden_runner with:

```console
dart pub global activate --source path ../golden_runner
```

## Run golden tests:

```
# run all tests
goldens test

# run a single test
goldens test --plain-name "something"

# run all tests in a directory
goldens test test my_dir

# run a single test in a directory
goldens test --plain-name "something" my_dir
```

## Update golden files:

```
# update all goldens
goldens update

# update all goldens in a directory
goldens update my_dir

# update a single golden
goldens update --plain-name "something"

# update a single golden in a directory
goldens update --plain-name "something" my_dir
```


## Flow-layout tests

Run from the package root:

```sh
flutter test test/flow_layout
```

The suite covers wrapping, fragmentation, custom participants, widgets, obstacles,
carets and selection geometry, caches, compact fitting, and Unicode conformance.
Its fonts and custom participant are test-only; the package has no runtime
font dependency. The complete Unicode corpus is included under
`test/flow_layout/data/unicode/`.

Browser-compatible tests can also run with Flutter's Chrome test platform:

```sh
flutter test --platform chrome test/flow_layout/compact_integration_test.dart test/flow_layout/padded_compact_test.dart
```

Example UI tests remain in `example/test/`. Benchmark-tool and exploratory study
tests live in `performance/test/`; native timing tests live in
`performance/integration_test/`. Run performance commands from `performance/`.
