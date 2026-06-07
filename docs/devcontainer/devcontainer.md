# Optional DevContainer workflow

This document describes an optional VS Code DevContainer workflow for users or contributors who want a reproducible Godot Dart setup.

This is **not** the recommended installation path for Godot Dart. The standard setup remains the one described in the main `README.md`.

The goal of this workflow is to make it easier to:

- create a normal Godot project first;
- add a `.devcontainer/` folder inside that Godot project;
- add a setup script under `scripts/install.sh`;
- install Dart and the required command-line tools inside the container;
- download the prebuilt Godot Dart extension artifact;
- run `dart pub get` and `build_runner` in a controlled environment;
- avoid common host/container path issues.

## Scope

This workflow is optional.

It does not replace:

- the standard setup in `README.md`;
- the source build flow in `CONTRIBUTING.md`;
- the existing `prepare.sh`;
- the existing `tools/fetch_dart` workflow.

The helper script provided in this repository is intended as a reference script.

In this repository, the reference script lives under:

```text
docs/devcontainer/install.sh
```

In a real Godot project, the intended workflow is to copy or adapt that script into the Godot project itself, usually under:

```text
scripts/install.sh
```

Then the project-local `.devcontainer/devcontainer.json` can run it with:

```json
"postCreateCommand": "bash scripts/install.sh"
```

## Requirements

You need:

- Docker;
- VS Code;
- the VS Code Dev Containers extension;
- a GitHub token or a direct artifact URL;
- optionally, Godot installed on the host if you choose the host-first workflow.

## Recommended workflow

This workflow assumes that you create a Godot project first.

Start with a normal Godot project:

```text
my_godot_project/
├── project.godot
├── icon.svg
└── main.tscn
```

Then add the DevContainer and setup files inside that Godot project:

```text
my_godot_project/
├── .devcontainer/
│   └── devcontainer.json
├── scripts/
│   └── install.sh
├── project.godot
├── icon.svg
└── main.tscn
```

The `.devcontainer/devcontainer.json` file configures the container used by VS Code, and `scripts/install.sh` performs the Godot Dart setup after the container is created.

## Files provided in this repository

This repository provides the reference documentation and helper script under:

```text
docs/devcontainer/
├── devcontainer.md
└── install.sh
```

These files are meant to document the approach and provide a reference implementation.

For a real Godot project, copy or adapt the helper script into your project:

```text
my_godot_project/
└── scripts/
    └── install.sh
```

## Expected project layout after installation

After the prebuilt artifact is extracted, a working Godot Dart project may look like this:

```text
my_godot_project/
├── project.godot
├── godot_dart.gdextension
├── libgodot_dart.so
├── libdart_dll.so
├── godot_dart/
│   └── logo_dart.svg
└── src/
    ├── analysis_options.yaml
    ├── pubspec.yaml
    ├── main.dart
    ├── godot_dart_scripts.g.dart
    └── lib/
```

The exact native libraries may vary by platform. For example, the downloaded artifact may contain:

```text
libgodot_dart.so
libgodot_dart.dylib
godot_dart.dll
libdart_dll.so
libdart_dll.dylib
dart_dll.dll
```

The important point is that the native libraries and `godot_dart.gdextension` must be available from the Godot project root, next to `project.godot`.

## Environment variables

The install script can download the prebuilt Godot Dart artifact in two ways:

1. using a GitHub token;
2. using a direct artifact URL.

Create a local `.env` file at the Godot project root:

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

For a Godot project using this workflow, the `.gitignore` should usually include:

```gitignore
.env
install.log
build_runner.log
.cache/
.pub-cache/
.dart_tool/
src/.dart_tool/
src/build_runner.log
```

Be careful with `pubspec.lock`: some repositories intentionally commit lockfiles, especially examples or tools. Do not ignore or remove `pubspec.lock` globally unless that is the intended policy for the project.

## Important rule: do not mix environments

The most important rule is:

> The environment that runs `dart pub get` and `build_runner` should be the same environment that runs Godot.

This matters because `dart pub get` writes `.dart_tool/package_config.json`. That file contains package resolution paths. If it is generated inside a container, it may contain paths such as:

```text
/workspaces/my_godot_project/.pub-cache/...
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

Run the helper script with `SKIP_DART_SETUP=1` from the Godot project root:

```bash
SKIP_DART_SETUP=1 bash scripts/install.sh
```

Then run the Dart setup on the host:

```bash
cd src
dart pub get
dart run build_runner build --delete-conflicting-outputs
cd ..
```

Launch Godot on the host from the project root:

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

Run the helper script from the Godot project root:

```bash
bash scripts/install.sh
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

Example `.devcontainer/devcontainer.json` for a Godot project using this workflow:

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

  "postCreateCommand": "bash scripts/install.sh",

  "runArgs": [
    "-e",
    "DISPLAY",
    "-v",
    "/tmp/.X11-unix:/tmp/.X11-unix"
  ]
}
```

The important parts are:

```json
"containerEnv": {
  "PUB_CACHE": "/workspaces/${localWorkspaceFolderBasename}/.pub-cache"
}
```

and:

```json
"postCreateCommand": "bash scripts/install.sh"
```

This keeps the Dart pub cache inside the project workspace and makes the setup reproducible after the container is created.

## Install script behavior

The install script:

1. installs minimal system dependencies;
2. installs the Dart SDK if missing;
3. loads `.env` if present;
4. downloads the prebuilt `godot-extension` artifact;
5. extracts it into the Godot project root;
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
SKIP_DART_SETUP=1 bash scripts/install.sh
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
GODOT_DART_ARTIFACT_URL="https://..." bash scripts/install.sh
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

### Native libraries are not found after extraction

Check that the native libraries were extracted at the Godot project root:

```bash
ls -la libgodot_dart.so libdart_dll.so godot_dart.gdextension
```

On other platforms, check for the corresponding files:

```bash
ls -la godot_dart.dll dart_dll.dll
ls -la libgodot_dart.dylib libdart_dll.dylib
```

If the files exist but Godot still cannot load them on Linux, launch Godot with:

```bash
LD_LIBRARY_PATH="$PWD:$LD_LIBRARY_PATH" godot -e
```

## Notes for future changes

Godot Dart may evolve toward a workflow where it downloads the proper Dart SDK, builds a kernel file, and uses that instead of the current compilation approach.

This DevContainer workflow should therefore stay small and defensive:

- avoid changing the core build system;
- avoid replacing the official install flow;
- keep the setup documented as optional;
- prefer prebuilt artifacts unless the contributor explicitly wants to work on the native build pipeline.