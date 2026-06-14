# Running Golden Tests
Golden tests must be run locally with `golden_runner`, which runs golden tests in an Ubuntu image.
This is done so that the goldens generated locally match the goldens that are tested in GitHub CI.

## Install Docker
In order to run the golden tests, Docker must be installed. See docs for installing Docker Desktop:
- macOS: https://docs.docker.com/desktop/install/mac-install/
- Linux: https://docs.docker.com/desktop/install/linux-install/
- Windows: https://docs.docker.com/desktop/install/windows-install/

## Activate Golden Runner
Golden tests must be run with `golden_runner` so that they're run in an Ubuntu image.

    dart pub global activate golden_runner

## Run golden tests:
You can run golden tests with two different approaches.

You can run or update all goldens using scripts inside of this project:

    # Test
    ./test_goldens_verify.sh

    # Update
    ./test_goldens_update.sh

Alternatively, you can run tests directly, which also gives you the freedom to run just a
subset of tests. To do this, you need to take care to specify the `--path-to-project-root` when
running the `golden_runner`. This is because `super_editor` golden tests must be run from the 
`super_editor/super_editor` package directory, but the Docker image must be built from the 
monorepo root so that sibling packages like `attributed_text` and `super_text_layout` exist
inside the container.

### Run golden tests directly:
```
# Run all tests
goldens test --path-to-project-root=..

# Run a single test
goldens test --path-to-project-root=.. --plain-name "something"

# Run all tests in a directory
goldens test --path-to-project-root=.. test_goldens/my_dir

# Run a single test in a directory
goldens test --path-to-project-root=.. --plain-name "something" test_goldens/my_dir
```

## Update golden files directly:
```
# update all goldens
goldens update --path-to-project-root=..

# update all goldens in a directory
goldens update --path-to-project-root=.. test_goldens/my_dir

# update a single golden
goldens update --path-to-project-root=.. --plain-name "something"

# update a single golden in a directory
goldens update --path-to-project-root=.. --plain-name "something" test_goldens/my_dir
```
