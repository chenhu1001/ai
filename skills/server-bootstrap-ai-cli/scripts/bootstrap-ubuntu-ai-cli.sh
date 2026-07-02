#!/usr/bin/env bash
set -euo pipefail

GIT_NAME=""
GIT_EMAIL=""
GENERATE_GITHUB_KEY=0
GITHUB_KEY_COMMENT=""
CONFIGURE_SSH_KEEPALIVE=0

usage() {
  cat <<'USAGE'
Usage:
  bootstrap-ubuntu-ai-cli.sh [options]

Options:
  --git-name NAME              Configure git user.name.
  --git-email EMAIL            Configure git user.email.
  --generate-github-key        Generate ~/.ssh/id_ed25519 if it does not exist.
  --github-key-comment TEXT    SSH key comment. Defaults to server-<public-ip-or-hostname>.
  --configure-ssh-keepalive    Add server-side sshd keepalive drop-in and reload ssh.
  -h, --help                   Show this help.

The script installs Git, tmux, Docker Engine, Node.js 22, Claude Code, Codex CLI,
and OpenCode. It never prints private SSH keys.
USAGE
}

log() {
  printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --git-name)
      GIT_NAME="${2:?missing value for --git-name}"
      shift 2
      ;;
    --git-email)
      GIT_EMAIL="${2:?missing value for --git-email}"
      shift 2
      ;;
    --generate-github-key)
      GENERATE_GITHUB_KEY=1
      shift
      ;;
    --github-key-comment)
      GITHUB_KEY_COMMENT="${2:?missing value for --github-key-comment}"
      shift 2
      ;;
    --configure-ssh-keepalive)
      CONFIGURE_SSH_KEEPALIVE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root or with sudo." >&2
    exit 1
  fi
}

install_base_tools() {
  log "Installing base tools"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y git tmux ca-certificates curl tar gzip unzip xz-utils
}

install_docker() {
  log "Installing Docker Engine"
  apt-get remove -y docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc 2>/dev/null || true
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  local suite arch
  suite="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"
  arch="$(dpkg --print-architecture)"
  cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${suite}
Components: stable
Architectures: ${arch}
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
}

install_node22() {
  local major="0"
  if command -v node >/dev/null 2>&1; then
    major="$(node -p 'process.versions.node.split(".")[0]')"
  fi
  if [ "${major}" -ge 22 ] 2>/dev/null; then
    log "Node.js $(node --version) is already >= 22"
    return
  fi

  log "Installing Node.js 22 from NodeSource"
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
}

install_ai_cli_tools() {
  log "Installing Claude Code, Codex CLI, and OpenCode"
  if ! curl -fsSL https://claude.ai/install.sh | bash; then
    npm install -g @anthropic-ai/claude-code@latest
  fi

  if ! curl -fsSL https://chatgpt.com/codex/install.sh | bash -s -- --yes; then
    npm install -g @openai/codex@latest
  fi

  if ! curl -fsSL https://opencode.ai/install | bash; then
    npm install -g opencode-ai@latest
  fi

  cat > /etc/profile.d/ai-cli-tools.sh <<'EOF'
# AI CLI tools installed by bootstrap-ubuntu-ai-cli.sh
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.codex/bin:$HOME/.claude/local:$PATH"
EOF
  chmod 0644 /etc/profile.d/ai-cli-tools.sh
  export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.codex/bin:$HOME/.claude/local:$PATH"
}

configure_git_identity() {
  if [ -n "${GIT_NAME}" ]; then
    git config --global user.name "${GIT_NAME}"
  fi
  if [ -n "${GIT_EMAIL}" ]; then
    git config --global user.email "${GIT_EMAIL}"
  fi
}

configure_github_key() {
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh

  if [ "${GENERATE_GITHUB_KEY}" -eq 1 ]; then
    if [ -f ~/.ssh/id_ed25519 ]; then
      log "SSH key ~/.ssh/id_ed25519 already exists; leaving it unchanged"
    else
      if [ -z "${GITHUB_KEY_COMMENT}" ]; then
        local public_ip
        public_ip="$(curl -fsSL --max-time 5 https://api.ipify.org || hostname)"
        GITHUB_KEY_COMMENT="server-${public_ip}"
      fi
      ssh-keygen -t ed25519 -C "${GITHUB_KEY_COMMENT}" -f ~/.ssh/id_ed25519 -N ""
    fi
  fi

  if [ -f ~/.ssh/id_ed25519.pub ]; then
    log "GitHub public key. Add this to GitHub Settings -> SSH and GPG keys:"
    cat ~/.ssh/id_ed25519.pub
  else
    log "No ~/.ssh/id_ed25519.pub found. Re-run with --generate-github-key if needed."
  fi
}

configure_ssh_keepalive() {
  if [ "${CONFIGURE_SSH_KEEPALIVE}" -ne 1 ]; then
    return
  fi

  log "Configuring server-side SSH keepalive"
  cat > /etc/ssh/sshd_config.d/99-keepalive.conf <<'EOF'
# Keep SSH sessions alive across idle network/NAT timeouts.
ClientAliveInterval 60
ClientAliveCountMax 120
TCPKeepAlive yes
EOF
  sshd -t
  systemctl reload ssh
}

verify_versions() {
  log "Installed versions"
  git --version || true
  tmux -V || true
  docker --version || true
  docker compose version || true
  node --version || true
  npm --version || true
  claude --version || true
  codex --version || true
  opencode --version || true
  git config --global --list || true
}

main() {
  require_root
  install_base_tools
  install_docker
  install_node22
  install_ai_cli_tools
  configure_git_identity
  configure_github_key
  configure_ssh_keepalive
  verify_versions

  log "Done. Use tmux new -s ai, detach with Ctrl+B then D, and restore with tmux attach -t ai."
}

main "$@"
