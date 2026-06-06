#!/usr/bin/env bash

set -euo pipefail

# -----------------------------------------------------------------------------
# Optional DevContainer installer for Godot Dart sample/project setup.
#
# This script:
# - installs minimal system dependencies;
# - installs the Dart SDK if missing;
# - downloads the prebuilt Godot Dart GitHub Actions artifact;
# - extracts it into the project root;
# - optionally runs dart pub get + build_runner in ./src.
#
# Important:
# The environment that runs `dart pub get` / `build_runner` should be the same
# environment that runs Godot. Otherwise .dart_tool/package_config.json may
# contain paths that are invalid at runtime.
#
# Use SKIP_DART_SETUP=1 for a host-first workflow where Dart setup is run on the
# host instead of inside the DevContainer.
# -----------------------------------------------------------------------------

REPO="${GODOT_DART_REPO:-fuzzybinary/godot_dart}"
ARTIFACT_NAME="${GODOT_DART_ARTIFACT_NAME:-godot-extension}"
LOG_FILE="${LOG_FILE:-install.log}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CACHE_DIR="${PROJECT_ROOT}/.cache"
ZIP_OUT="${CACHE_DIR}/${ARTIFACT_NAME}.zip"

mkdir -p "${CACHE_DIR}"

exec > >(tee -a "${PROJECT_ROOT}/${LOG_FILE}") 2>&1

log() {
  echo "==> $*"
}

warn() {
  echo "⚠️  $*" >&2
}

fail() {
  echo "❌ $*" >&2
  exit 1
}

has_command() {
  command -v "$1" >/dev/null 2>&1
}

load_env_file() {
  if [ -f "${PROJECT_ROOT}/.env" ]; then
    log "Loading .env"
    set -a
    # shellcheck disable=SC1091
    . "${PROJECT_ROOT}/.env"
    set +a
  fi
}

install_system_dependencies() {
  log "Installing system dependencies"

  sudo apt-get update
  sudo apt-get install -y \
    ca-certificates \
    curl \
    gpg \
    git \
    jq \
    unzip \
    wget
}

install_dart_if_missing() {
  if has_command dart; then
    log "Dart already installed: $(dart --version 2>&1 || true)"
    return
  fi

  log "Installing Dart SDK"

  curl -fsSL https://dl-ssl.google.com/linux/linux_signing_key.pub \
    | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg

  echo "deb [signed-by=/usr/share/keyrings/dart.gpg] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main" \
    | sudo tee /etc/apt/sources.list.d/dart_stable.list >/dev/null

  sudo apt-get update
  sudo apt-get install -y dart

  echo 'export PATH="/usr/lib/dart/bin:$PATH"' \
    | sudo tee /etc/profile.d/dart.sh >/dev/null

  log "Dart installed: $(dart --version 2>&1 || true)"
}

download_artifact_with_token() {
  : "${GITHUB_TOKEN:?GITHUB_TOKEN is required to download the latest GitHub Actions artifact}"

  log "Searching latest successful workflow runs for artifact '${ARTIFACT_NAME}'"

  local runs_json
  runs_json="$(
    curl -fsSL \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      "https://api.github.com/repos/${REPO}/actions/runs?status=success&per_page=10"
  )"

  local run_ids
  run_ids="$(echo "${runs_json}" | jq -r '.workflow_runs[].id')"

  [ -n "${run_ids}" ] || fail "No successful workflow run found for ${REPO}"

  local run_id=""
  local artifact_id=""

  while IFS= read -r candidate_run_id; do
    [ -n "${candidate_run_id}" ] || continue

    log "Checking workflow run ${candidate_run_id}"

    local artifacts_json
    artifacts_json="$(
      curl -fsSL \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        "https://api.github.com/repos/${REPO}/actions/runs/${candidate_run_id}/artifacts"
    )"

    artifact_id="$(
      echo "${artifacts_json}" \
        | jq -r ".artifacts[] | select(.name == \"${ARTIFACT_NAME}\") | .id" \
        | head -n 1
    )"

    if [ -n "${artifact_id}" ] && [ "${artifact_id}" != "null" ]; then
      run_id="${candidate_run_id}"
      break
    fi
  done <<< "${run_ids}"

  [ -n "${run_id}" ] || fail "Artifact '${ARTIFACT_NAME}' not found in the latest successful runs"

  log "Downloading artifact '${ARTIFACT_NAME}' from run ${run_id}, artifact id=${artifact_id}"

  curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -o "${ZIP_OUT}" \
    "https://api.github.com/repos/${REPO}/actions/artifacts/${artifact_id}/zip"
}

download_artifact_with_url() {
  : "${GODOT_DART_ARTIFACT_URL:?GODOT_DART_ARTIFACT_URL is required}"

  log "Downloading artifact from GODOT_DART_ARTIFACT_URL"
  curl -fL -o "${ZIP_OUT}" "${GODOT_DART_ARTIFACT_URL}"
}

download_artifact() {
  rm -f "${ZIP_OUT}"

  if [ -n "${GITHUB_TOKEN:-}" ]; then
    download_artifact_with_token
  elif [ -n "${GODOT_DART_ARTIFACT_URL:-}" ]; then
    download_artifact_with_url
  else
    fail "No artifact source configured. Set GITHUB_TOKEN or GODOT_DART_ARTIFACT_URL in .env."
  fi

  [ -s "${ZIP_OUT}" ] || fail "Downloaded artifact is empty: ${ZIP_OUT}"
}

extract_artifact() {
  log "Extracting artifact into project root: ${PROJECT_ROOT}"
  unzip -o "${ZIP_OUT}" -d "${PROJECT_ROOT}"

  [ -d "${PROJECT_ROOT}/src" ] || fail "No ./src directory found after extracting artifact"
}

ensure_gdextension_file() {
  if [ -f "${PROJECT_ROOT}/godot_dart.gdextension" ]; then
    log "godot_dart.gdextension already exists"
    return
  fi

  warn "godot_dart.gdextension not found after extraction; writing fallback file"

  cat > "${PROJECT_ROOT}/godot_dart.gdextension" <<'EOF'
[configuration]
entry_symbol = "godot_dart_init"
compatibility_minimum = 4.2

[icons]
DartScript = "res://godot_dart/logo_dart.svg"
DartHotReload = "res://godot_dart/hot_reload.svg"

[libraries]
linux.debug.x86_64 = "res://libgodot_dart.so"
linux.release.x86_64 = "res://libgodot_dart.so"
windows.debug.x86_64 = "res://godot_dart.dll"
windows.release.x86_64 = "res://godot_dart.dll"
macos.debug = "res://libgodot_dart.dylib"
macos.release = "res://libgodot_dart.dylib"
EOF
}

run_dart_setup() {
  if [ "${SKIP_DART_SETUP:-0}" = "1" ]; then
    log "Skipping Dart setup because SKIP_DART_SETUP=1"
    cat <<EOF
==> Host-first workflow selected.

Run these commands in the same environment that will launch Godot:

  cd src
  dart pub get
  dart run build_runner build --delete-conflicting-outputs

Then launch Godot from the project root, for example:

  LD_LIBRARY_PATH="\$PWD:\$LD_LIBRARY_PATH" godot -e

EOF
    return
  fi

  log "Running Dart setup inside this environment"

  local pub_cache
  pub_cache="${PUB_CACHE:-${PROJECT_ROOT}/.pub-cache}"
  mkdir -p "${pub_cache}"

  (
    cd "${PROJECT_ROOT}/src"

    log "dart pub get"
    PUB_CACHE="${pub_cache}" dart pub get

    if [ -d "lib" ]; then
      log "dart run build_runner build --delete-conflicting-outputs"
      PUB_CACHE="${pub_cache}" dart run build_runner build --delete-conflicting-outputs
    else
      warn "./src/lib not found; skipping build_runner"
    fi
  )

  log "Dart setup complete"
  log "PUB_CACHE=${pub_cache}"
}

print_summary() {
  cat <<EOF

✅ Godot Dart setup complete.

Project root:
  ${PROJECT_ROOT}

Log file:
  ${PROJECT_ROOT}/${LOG_FILE}

Important:
  Do not mix Dart setup and Godot runtime environments.

  If this script ran 'dart pub get' inside the DevContainer,
  then Godot should also run inside the DevContainer.

  If you want to run Godot on the host, prefer:
    SKIP_DART_SETUP=1 bash scripts/install.sh

  Then run 'dart pub get' and 'build_runner' on the host.

EOF
}

main() {
  log "Project root: ${PROJECT_ROOT}"
  log "User: $(whoami)"
  log "Repository: ${REPO}"
  log "Artifact name: ${ARTIFACT_NAME}"

  load_env_file
  install_system_dependencies
  install_dart_if_missing
  download_artifact
  extract_artifact
  ensure_gdextension_file
  run_dart_setup
  print_summary
}

main "$@"