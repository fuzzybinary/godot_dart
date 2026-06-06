# Optional DevContainer workflow

This document describes an optional VS Code DevContainer workflow for users or contributors who want a reproducible Godot Dart setup.

This is **not** the recommended installation path for Godot Dart. The standard setup remains the one described in the main `README.md`.

The goal of this workflow is to make it easier to:

- open a project in a reproducible Linux container;
- install Dart and the required command-line tools;
- download the prebuilt Godot Dart extension artifact;
- run `dart pub get` and `build_runner` in a controlled environment;
- avoid common host/container path issues.

## Requirements

You need:

- Docker;
- VS Code;
- the VS Code Dev Containers extension;
- a GitHub token or a direct artifact URL;
- optionally, Godot installed on the host if you choose the host-first workflow.

## Files added by this workflow

A suggested layout is:

```text
docs/devcontainer/
├── README.md
└── install.sh

or

example/
└── devcontainer/
    ├── devcontainer.json
    └── install.sh
```

## Environment variables

The install script can download the prebuilt Godot Dart artifact in two ways:

1. using a GitHub token;
2. using a direct artifact URL.

Create a local `.env` file at the project root:

```bash
cp .env.example .env
```

Then edit `.env`.

Example:

```bash
# GitHub personal access token used to download the latest GitHub Actions artifact.
# Do not commit your real token.
GITHUB_TOKEN=

# Optional fallback: direct artifact URL if you do not want to use a token.
GODOT_DART_ARTIFACT_URL=
```

Do not commit `.env`.

A token is only needed so the script can query and download the latest successful GitHub Actions artifact. Prefer a fine-grained token with the minimum required permissions and an expiration date.

The `.gitignore` should include:

```gitignore
.env
install.log
build_runner.log
.cache/
.pub-cache/
.dart_tool/
```

## Important rule: do not mix environments

The most important rule is:

> The environment that runs `dart pub get` and `build_runner` should be the same environment that runs Godot.

This matters because `dart pub get` writes `.dart_tool/package_config.json`. That file contains package resolution paths. If it is generated inside a container, it may contain paths such as:

```text
/workspaces/godot_dart_sample_app/.pub-cache/...
```

If Godot is later launched on the host, those container paths may not exist on the host, and Godot Dart may fail with an error similar to:

```text
Error when reading '/workspaces/.../godot_dart/lib/godot_dart.dart':
No such file or directory
```

To avoid this, choose one workflow and stick to it.

## Workflow A: host-first

Use this workflow if you want to run Godot on the host.

In this mode, the DevContainer can download and extract the prebuilt extension, but it should **not** run `dart pub get` or `build_runner`.

Run:

```bash
SKIP_DART_SETUP=1 bash example/devcontainer/install.sh
```

Then run the Dart setup on the host:

```bash
cd src
dart pub get
dart run build_runner build --delete-conflicting-outputs
cd ..
```

Launch Godot on the host:

```bash
LD_LIBRARY_PATH="$PWD:$LD_LIBRARY_PATH" godot -e
```

Use this workflow when:

- Godot is installed on the host;
- you want Godot to run outside the container;
- you want `.dart_tool/package_config.json` to contain host paths.

## Workflow B: container-first

Use this workflow if you want the DevContainer to own the full Dart setup.

In this mode, the install script runs:

```bash
dart pub get
dart run build_runner build --delete-conflicting-outputs
```

inside the container.

Run:

```bash
bash example/devcontainer/install.sh
```

Then Godot should also be launched from inside the same container.

Example:

```bash
LD_LIBRARY_PATH="$PWD:$LD_LIBRARY_PATH" godot -e
```

This requires Godot to be available inside the container and may require additional display forwarding setup such as X11 or Wayland passthrough.

Use this workflow when:

- you want full isolation;
- you want container-local Dart dependencies;
- you are comfortable running Godot from inside the container.

## DevContainer configuration

Example `example/devcontainer/devcontainer.json`:

```json
{
  "name": "Godot + Dart DevContainer",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu-22.04",
  "workspaceFolder": "/workspaces/${localWorkspaceFolderBasename}",

  "customizations": {
    "vscode": {
      "extensions": [
        "Dart-Code.dart-code",
        "geequlim.godot-tools",
        "ms-vscode.cpptools",
        "ms-vscode.cmake-tools"
      ]
    }
  },

  "remoteUser": "vscode",
  "updateRemoteUserUID": false,

  "containerEnv": {
    "PUB_CACHE": "/workspaces/${localWorkspaceFolderBasename}/.pub-cache"
  },

  "postCreateCommand": "bash example/devcontainer/install.sh",

  "runArgs": [
    "-e",
    "DISPLAY",
    "-v",
    "/tmp/.X11-unix:/tmp/.X11-unix"
  ]
}
```

## Install script behavior

The install script:

1. installs minimal system dependencies;
2. installs the Dart SDK if missing;
3. loads `.env` if present;
4. downloads the prebuilt `godot-extension` artifact;
5. extracts it into the project root;
6. ensures a `godot_dart.gdextension` file exists;
7. optionally runs `dart pub get` and `build_runner`;
8. writes an `install.log` file.

The script supports these environment variables:

```bash
GITHUB_TOKEN
GODOT_DART_ARTIFACT_URL
GODOT_DART_REPO
GODOT_DART_ARTIFACT_NAME
SKIP_DART_SETUP
PUB_CACHE
LOG_FILE
```

### `GITHUB_TOKEN`

Used to query the GitHub Actions API and download the latest successful artifact.

### `GODOT_DART_ARTIFACT_URL`

Optional fallback if you want to provide a direct artifact URL instead of using a token.

### `SKIP_DART_SETUP`

Set this to `1` for the host-first workflow:

```bash
SKIP_DART_SETUP=1 bash example/devcontainer/install.sh
```

When enabled, the script downloads and extracts the extension but does not run:

```bash
dart pub get
dart run build_runner build
```

### `PUB_CACHE`

Overrides the Dart pub cache location.

Default:

```bash
PUB_CACHE="${PROJECT_ROOT}/.pub-cache"
```

### Why use a project-local `PUB_CACHE`?

When working across a host machine and a DevContainer, using a project-local `PUB_CACHE` can make troubleshooting easier:

```bash
PUB_CACHE="$PWD/../.pub-cache" dart pub get
```

This avoids relying on environment-specific default cache locations such as:

```text
/home/vscode/.pub-cache
/home/<user>/.pub-cache
```

However, this does **not** make host/container mixing safe by itself.

The important part is still that `dart pub get`, `build_runner`, and Godot must run in the same environment.

## Troubleshooting

### `package:godot_dart/godot_dart.dart` not found

This usually means that `.dart_tool/package_config.json` was generated in a different environment from the one running Godot.

For example:

- `dart pub get` ran in the container;
- Godot ran on the host.

In that case, `.dart_tool/package_config.json` may contain container paths such as:

```text
/workspaces/<project>/.pub-cache/...
```

Those paths may not exist from the host environment, so Godot Dart cannot resolve imports such as:

```dart
import 'package:godot_dart/godot_dart.dart';
```

Fix the issue by regenerating the Dart package resolution in the same environment that will launch Godot:

```bash
cd src
rm -rf .dart_tool pubspec.lock
PUB_CACHE="$PWD/../.pub-cache" dart pub get
PUB_CACHE="$PWD/../.pub-cache" dart run build_runner build --delete-conflicting-outputs &> build_runner.log
cd ..
LD_LIBRARY_PATH="$PWD:$LD_LIBRARY_PATH" godot -e
```

This does four things:

1. removes stale Dart resolution files generated in another environment;
2. forces Dart to use a project-local `.pub-cache`;
3. regenerates the Godot Dart generated files with `build_runner`;
4. launches Godot with the project root added to `LD_LIBRARY_PATH`, so the native extension libraries can be found.

Make sure these commands are executed in the same environment where Godot will run.

### Dart analyzer errors in VS Code

Before code generation runs, the Dart analyzer may report missing generated symbols.

Run:

```bash
cd src
dart run build_runner build --delete-conflicting-outputs
```

Then reload VS Code or restart the Dart analyzer if needed.

### `No ./src found after extracting artifact`

The downloaded artifact may not have the expected layout.

Check:

```bash
ls -la
ls -la src
```

You can also provide a direct artifact URL:

```bash
GODOT_DART_ARTIFACT_URL="https://..." bash example/devcontainer/install.sh
```

### GitHub token issues

If the script cannot download the artifact, check that:

- `.env` exists;
- `GITHUB_TOKEN` is set;
- the token is not expired;
- the token has enough permissions to read repository Actions artifacts.

### Godot cannot load `libgodot_dart.so`

If Godot cannot find the native library, launch it from the project root with:

```bash
LD_LIBRARY_PATH="$PWD:$LD_LIBRARY_PATH" godot -e
```

If the error mentions `GLIBCXX`, the downloaded binary may require a newer `libstdc++` than the one available on the host. In that case, either run Godot in a compatible environment or use an artifact built with a compatible toolchain.

## Recommended PR scope

This workflow should be treated as optional documentation and tooling.

It should not replace:

- the standard setup in `README.md`;
- the source build flow in `CONTRIBUTING.md`;
- the existing `prepare.sh`;
- the existing `tools/fetch_dart` workflow.

Suggested PR scope:

```text
docs/devcontainer.md
example/devcontainer/devcontainer.json
example/devcontainer/install.sh
README.md
.env.example
.gitignore
```

Suggested README addition:

```md
### Optional DevContainer workflow

For users or contributors who want a reproducible VS Code DevContainer setup, see [docs/devcontainer.md](docs/devcontainer.md).

This is an optional workflow and does not replace the standard setup described above.
```

## Notes for future changes

Godot Dart may evolve toward a workflow where it downloads the proper Dart SDK, builds a kernel file, and uses that instead of the current compilation approach.

This DevContainer workflow should therefore stay small and defensive:

- avoid changing the core build system;
- avoid replacing the official install flow;
- keep the setup documented as optional;
- prefer prebuilt artifacts unless the contributor explicitly wants to work on the native build pipeline.