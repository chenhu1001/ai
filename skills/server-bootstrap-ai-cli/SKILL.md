---
name: server-bootstrap-ai-cli
description: Bootstrap a fresh Ubuntu/root server for coding and AI-agent work. Use when the user asks to install or document server setup steps for Git, Docker Engine, GitHub SSH keys, Git user.name/user.email, tmux/screen-like persistent shells, SSH keepalive, and command-line AI tools such as Claude Code, OpenAI Codex CLI, and OpenCode, especially when they want the process consolidated into a repeatable script or runbook.
---

# Server Bootstrap AI CLI

## Overview

Use this skill to prepare an Ubuntu server for remote development and long-running AI CLI sessions. Prefer a documented, repeatable flow over ad hoc terminal commands, and make security-sensitive values explicit placeholders rather than embedding secrets.

## Workflow

1. Confirm target OS/user and access method. The bundled script assumes Ubuntu/Debian with root privileges.
2. Install base tools: `git`, `tmux`, `curl`, `ca-certificates`, archive tools.
3. Install Docker Engine from Docker's official apt repository.
4. Configure GitHub SSH:
   - Generate an ed25519 key only when requested or when no key exists.
   - Show the public key and tell the user to add it under GitHub `Settings -> SSH and GPG keys`.
   - Never print or copy private key contents.
5. Configure Git identity with user-provided `user.name` and `user.email`; do not invent an email address.
6. Install Node.js 22 and the latest Claude Code, Codex CLI, and OpenCode CLI.
7. Configure persistent shell usage with `tmux`, and optionally SSH keepalive.
8. Verify versions and summarize exact commands, paths, and remaining manual actions.

## Script

Use `scripts/bootstrap-ubuntu-ai-cli.sh` when the user wants an executable installer or a consolidated script. Read the script before running or copying it if you need to adjust defaults.

Typical usage on the server:

```bash
bash bootstrap-ubuntu-ai-cli.sh \
  --git-name "Your Name" \
  --git-email "you@example.com" \
  --generate-github-key
```

If an SSH key already exists and should be reused, omit `--generate-github-key`.

## Verification Checklist

Run or report:

- `git --version`
- `docker --version`
- `docker compose version`
- `tmux -V`
- `node --version`
- `npm --version`
- `claude --version`
- `codex --version`
- `opencode --version`
- `git config --global --list`
- `cat ~/.ssh/id_ed25519.pub` only for the public key

## Notes

- Claude Code currently requires Node.js 22 or newer when installed from npm.
- Official install scripts can fail due to region or access restrictions; fallback to `npm install -g @anthropic-ai/claude-code@latest`, `npm install -g @openai/codex@latest`, and `npm install -g opencode-ai@latest`.
- For long-running interactive sessions, recommend `tmux new -s ai`, detach with `Ctrl+B` then `D`, and restore with `tmux attach -t ai`.
