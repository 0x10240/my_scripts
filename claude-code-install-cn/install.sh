#!/usr/bin/env bash

set -euo pipefail

INSTALL_ROOT="${INSTALL_ROOT:-$HOME/.local/share/claude-code-cn}"
NODE_MIRROR_BASE_URL="${NODE_MIRROR_BASE_URL:-https://npmmirror.com/mirrors/node}"
NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmmirror.com}"
PACKAGE_NAME="${PACKAGE_NAME:-@anthropic-ai/claude-code}"
INSTALL_GIT="0"
BASE_URL=""
AUTH_TOKEN=""
API_KEY=""
CUSTOM_MODEL=""
EXTRA_PATH_PREFIX=""

log() {
  printf '[INFO] %s\n' "$1"
}

warn() {
  printf '[WARN] %s\n' "$1" >&2
}

fail() {
  printf '[ERROR] %s\n' "$1" >&2
  exit 1
}

run_with_privilege() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
    return
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
    return
  fi

  fail "Administrator privileges are required to install git. Re-run as root or install sudo."
}

find_brew_cmd() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return
  fi

  local candidate
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done
}

usage() {
  cat <<'EOF'
Usage:
  bash install.sh [options]

Options:
  --install-root PATH     Install root. Default: ~/.local/share/claude-code-cn
  --install-git           Automatically install git when missing
  --base-url URL          Persist ANTHROPIC_BASE_URL
  --auth-token TOKEN      Persist ANTHROPIC_AUTH_TOKEN
  --api-key KEY           Persist ANTHROPIC_API_KEY
  --custom-model MODEL    Persist ANTHROPIC_CUSTOM_MODEL_OPTION
  --registry URL          npm mirror URL. Default: https://registry.npmmirror.com
  --node-mirror URL       Node.js mirror URL. Default: https://npmmirror.com/mirrors/node
  -h, --help              Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-root)
      [[ $# -ge 2 ]] || fail "--install-root requires a value"
      INSTALL_ROOT="$2"
      shift 2
      ;;
    --install-git)
      INSTALL_GIT="1"
      shift
      ;;
    --base-url)
      [[ $# -ge 2 ]] || fail "--base-url requires a value"
      BASE_URL="$2"
      shift 2
      ;;
    --auth-token)
      [[ $# -ge 2 ]] || fail "--auth-token requires a value"
      AUTH_TOKEN="$2"
      shift 2
      ;;
    --api-key)
      [[ $# -ge 2 ]] || fail "--api-key requires a value"
      API_KEY="$2"
      shift 2
      ;;
    --custom-model)
      [[ $# -ge 2 ]] || fail "--custom-model requires a value"
      CUSTOM_MODEL="$2"
      shift 2
      ;;
    --registry)
      [[ $# -ge 2 ]] || fail "--registry requires a value"
      NPM_REGISTRY="$2"
      shift 2
      ;;
    --node-mirror)
      [[ $# -ge 2 ]] || fail "--node-mirror requires a value"
      NODE_MIRROR_BASE_URL="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

mkdir -p "$INSTALL_ROOT"

if ! command -v curl >/dev/null 2>&1; then
  fail "curl is required."
fi

if ! command -v tar >/dev/null 2>&1; then
  fail "tar is required."
fi

detect_node_major() {
  local version_text="$1"
  version_text="${version_text#v}"
  printf '%s' "${version_text%%.*}"
}

get_latest_lts_node_version() {
  local file_key="$1"
  local index_url="$NODE_MIRROR_BASE_URL/index.tab"
  local version

  version="$(
    curl -fsSL "$index_url" |
      awk -F'\t' -v key="$file_key" '
        NR > 1 {
          files="," $3 ","
          if ($10 != "-" && index(files, "," key ",") > 0) {
            print $1
            exit
          }
        }
      '
  )"

  [[ -n "$version" ]] || fail "Could not find a Node.js LTS release for $file_key from $index_url."
  printf '%s' "$version"
}

install_portable_node() {
  local uname_s arch version archive_name download_url tmp_dir final_node_dir extracted_dir file_key archive_name_suffix

  uname_s="$(uname -s)"
  arch="$(uname -m)"

  case "$uname_s" in
    Linux)
      case "$arch" in
        x86_64|amd64)
          file_key="linux-x64"
          archive_name_suffix="linux-x64.tar.xz"
          ;;
        aarch64|arm64)
          file_key="linux-arm64"
          archive_name_suffix="linux-arm64.tar.xz"
          ;;
        *)
          fail "Unsupported Linux architecture: $arch"
          ;;
      esac
      ;;
    Darwin)
      case "$arch" in
        x86_64)
          file_key="osx-x64-tar"
          archive_name_suffix="darwin-x64.tar.gz"
          ;;
        arm64)
          file_key="osx-arm64-tar"
          archive_name_suffix="darwin-arm64.tar.gz"
          ;;
        *)
          fail "Unsupported macOS architecture: $arch"
          ;;
      esac
      ;;
    *)
      fail "Unsupported OS: $uname_s"
      ;;
  esac

  version="$(get_latest_lts_node_version "$file_key")"
  archive_name="node-${version}-${archive_name_suffix}"
  download_url="$NODE_MIRROR_BASE_URL/$version/$archive_name"
  tmp_dir="$(mktemp -d)"
  final_node_dir="$INSTALL_ROOT/node"

  log "No usable Node.js found. Installing portable Node.js $version from the CN mirror."
  curl -fL "$download_url" -o "$tmp_dir/$archive_name"

  if [[ -d "$final_node_dir" ]]; then
    rm -rf "$final_node_dir"
  fi

  tar -xf "$tmp_dir/$archive_name" -C "$tmp_dir"
  extracted_dir="$(find "$tmp_dir" -maxdepth 1 -mindepth 1 -type d -name 'node-*' | head -n 1)"
  [[ -n "$extracted_dir" ]] || fail "Node.js extraction failed: extracted directory not found."

  mv "$extracted_dir" "$final_node_dir"
  rm -rf "$tmp_dir"

  printf '%s' "$final_node_dir"
}

install_git_linux() {
  if command -v apt-get >/dev/null 2>&1; then
    log "Installing git with apt-get"
    run_with_privilege env DEBIAN_FRONTEND=noninteractive apt-get update
    run_with_privilege env DEBIAN_FRONTEND=noninteractive apt-get install -y git
    return
  fi

  if command -v dnf >/dev/null 2>&1; then
    log "Installing git with dnf"
    run_with_privilege dnf install -y git
    return
  fi

  if command -v yum >/dev/null 2>&1; then
    log "Installing git with yum"
    run_with_privilege yum install -y git
    return
  fi

  if command -v zypper >/dev/null 2>&1; then
    log "Installing git with zypper"
    run_with_privilege zypper --non-interactive install git
    return
  fi

  if command -v pacman >/dev/null 2>&1; then
    log "Installing git with pacman"
    run_with_privilege pacman -Sy --noconfirm git
    return
  fi

  if command -v apk >/dev/null 2>&1; then
    log "Installing git with apk"
    run_with_privilege apk add --no-cache git
    return
  fi

  fail "git was not found and no supported Linux package manager was detected."
}

install_git_macos() {
  local brew_cmd=""
  local brew_prefix=""
  local brew_bin=""
  brew_cmd="$(find_brew_cmd || true)"
  if [[ -n "$brew_cmd" ]]; then
    log "Installing git with Homebrew"
    brew_bin="$(dirname "$brew_cmd")"
    export PATH="$brew_bin:$PATH"
    HOMEBREW_NO_AUTO_UPDATE=1 "$brew_cmd" install git
    brew_prefix="$("$brew_cmd" --prefix)"
    if [[ -n "$brew_prefix" && -d "$brew_prefix/bin" ]]; then
      EXTRA_PATH_PREFIX="$brew_prefix/bin"
      export PATH="$EXTRA_PATH_PREFIX:$PATH"
    fi
    return
  fi

  if command -v xcode-select >/dev/null 2>&1; then
    warn "Homebrew was not found. Triggering Apple's Command Line Tools installer for git."
    xcode-select --install >/dev/null 2>&1 || true
    fail "Finish the Command Line Tools installation dialog, then rerun this script."
  fi

  fail "git was not found and neither Homebrew nor xcode-select is available."
}

ensure_git() {
  if command -v git >/dev/null 2>&1; then
    log "Detected system Git: $(git --version)"
    return 0
  fi

  if [[ "$INSTALL_GIT" != "1" ]]; then
    warn "git was not found. Some Claude Code workflows rely on git."
    warn "Install git manually, or rerun this script with --install-git."
    return 1
  fi

  warn "git was not found. Installing git automatically."
  case "$(uname -s)" in
    Linux)
      install_git_linux
      ;;
    Darwin)
      install_git_macos
      ;;
    *)
      fail "git was not found and automatic installation is unsupported on this OS."
      ;;
  esac

  command -v git >/dev/null 2>&1 || fail "git installation did not complete successfully."
  log "Git installed successfully: $(git --version)"
  return 0
}

resolve_node_toolchain() {
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    local system_version major
    system_version="$(node --version)"
    major="$(detect_node_major "$system_version")"
    if [[ "$major" =~ ^[0-9]+$ ]] && (( major >= 18 )); then
      log "Detected system Node.js $system_version"
      NODE_BIN_DIR=""
      NODE_CMD="$(command -v node)"
      NPM_CMD="$(command -v npm)"
      USE_PORTABLE_NODE="0"
      return
    fi
    warn "System Node.js version is $system_version, below Claude Code's >= 18 requirement. Installing a portable Node.js."
  else
    warn "Node.js/npm not found. Installing a portable Node.js."
  fi

  NODE_HOME="$(install_portable_node)"
  NODE_BIN_DIR="$NODE_HOME/bin"
  NODE_CMD="$NODE_BIN_DIR/node"
  NPM_CMD="$NODE_BIN_DIR/npm"
  USE_PORTABLE_NODE="1"
}

write_env_file() {
  local env_file="$INSTALL_ROOT/env.sh"
  local prefix_bin="$INSTALL_ROOT/npm-global/bin"

  {
    printf '#!/usr/bin/env bash\n'
    if [[ -n "$EXTRA_PATH_PREFIX" && "$USE_PORTABLE_NODE" == "1" ]]; then
      printf 'export PATH=%q:%q:%q:$PATH\n' "$prefix_bin" "$NODE_BIN_DIR" "$EXTRA_PATH_PREFIX"
    elif [[ -n "$EXTRA_PATH_PREFIX" ]]; then
      printf 'export PATH=%q:%q:$PATH\n' "$prefix_bin" "$EXTRA_PATH_PREFIX"
    elif [[ "$USE_PORTABLE_NODE" == "1" ]]; then
      printf 'export PATH=%q:%q:$PATH\n' "$prefix_bin" "$NODE_BIN_DIR"
    else
      printf 'export PATH=%q:$PATH\n' "$prefix_bin"
    fi
    if [[ -n "$BASE_URL" ]]; then
      printf 'export ANTHROPIC_BASE_URL=%q\n' "$BASE_URL"
    fi
    if [[ -n "$AUTH_TOKEN" ]]; then
      printf 'export ANTHROPIC_AUTH_TOKEN=%q\n' "$AUTH_TOKEN"
    fi
    if [[ -n "$API_KEY" ]]; then
      printf 'export ANTHROPIC_API_KEY=%q\n' "$API_KEY"
    fi
    if [[ -n "$CUSTOM_MODEL" ]]; then
      printf 'export ANTHROPIC_CUSTOM_MODEL_OPTION=%q\n' "$CUSTOM_MODEL"
    fi
  } >"$env_file"

  chmod 600 "$env_file"
  ENV_FILE_PATH="$env_file"
}

ensure_profile_source_line() {
  local profile_file="$1"
  local source_line="test -f \"$ENV_FILE_PATH\" && . \"$ENV_FILE_PATH\""

  [[ -f "$profile_file" ]] || touch "$profile_file"

  if ! grep -Fqx "$source_line" "$profile_file" 2>/dev/null; then
    printf '\n%s\n' "$source_line" >>"$profile_file"
  fi
}

update_shell_profiles() {
  local wrote_profile="0"
  local profile

  for profile in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.profile"; do
    if [[ -f "$profile" ]]; then
      ensure_profile_source_line "$profile"
      wrote_profile="1"
    fi
  done

  if [[ "$wrote_profile" == "0" ]]; then
    ensure_profile_source_line "$HOME/.profile"
  fi
}

if ensure_git; then
  GIT_READY="1"
else
  GIT_READY="0"
fi
resolve_node_toolchain

PREFIX_DIR="$INSTALL_ROOT/npm-global"
CACHE_DIR="$INSTALL_ROOT/npm-cache"
mkdir -p "$PREFIX_DIR" "$CACHE_DIR"

if [[ "$USE_PORTABLE_NODE" == "1" ]]; then
  export PATH="$NODE_BIN_DIR:$PATH"
fi
export PATH="$PREFIX_DIR/bin:$PATH"

export NPM_CONFIG_REGISTRY="$NPM_REGISTRY"
export NPM_CONFIG_PREFIX="$PREFIX_DIR"
export NPM_CONFIG_CACHE="$CACHE_DIR"
export NPM_CONFIG_UPDATE_NOTIFIER="false"
export NPM_CONFIG_FUND="false"
export NPM_CONFIG_AUDIT="false"

log "Install root: $INSTALL_ROOT"
log "Installing $PACKAGE_NAME from the CN npm mirror"
"$NPM_CMD" install --global "$PACKAGE_NAME" --prefix "$PREFIX_DIR" --registry "$NPM_REGISTRY" --cache "$CACHE_DIR" --no-fund --no-audit

CLAUDE_BIN="$PREFIX_DIR/bin/claude"
[[ -x "$CLAUDE_BIN" ]] || fail "Install completed but $CLAUDE_BIN was not found."

write_env_file
update_shell_profiles

if [[ -n "$BASE_URL" ]]; then
  export ANTHROPIC_BASE_URL="$BASE_URL"
fi
if [[ -n "$AUTH_TOKEN" ]]; then
  export ANTHROPIC_AUTH_TOKEN="$AUTH_TOKEN"
fi
if [[ -n "$API_KEY" ]]; then
  export ANTHROPIC_API_KEY="$API_KEY"
fi
if [[ -n "$CUSTOM_MODEL" ]]; then
  export ANTHROPIC_CUSTOM_MODEL_OPTION="$CUSTOM_MODEL"
fi

CLAUDE_VERSION="$("$CLAUDE_BIN" --version)"
printf '[OK] Claude Code installed successfully: %s\n' "$CLAUDE_VERSION"
printf '\n'
printf 'Next steps:\n'
printf '1. Reopen your terminal, or run: . "%s"\n' "$ENV_FILE_PATH"
if [[ "$GIT_READY" == "1" ]]; then
  printf '2. Run: claude\n'
else
  printf '2. Install git manually, or rerun with --install-git.\n'
  printf '3. Run: claude\n'
fi
if [[ -z "$BASE_URL" && -z "$AUTH_TOKEN" && -z "$API_KEY" ]]; then
  if [[ "$GIT_READY" == "1" ]]; then
    printf '3. If you use a CN gateway/proxy, rerun this script with --base-url plus --auth-token or --api-key.\n'
  else
    printf '4. If you use a CN gateway/proxy, rerun this script with --base-url plus --auth-token or --api-key.\n'
  fi
fi
