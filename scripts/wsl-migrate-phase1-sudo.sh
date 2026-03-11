#!/usr/bin/env bash
# Phase 1: WSL 기반 도구 설치 (sudo 필요 - WSL 터미널에서 직접 실행)
set -euo pipefail

echo "=== Phase 1: 기반 도구 설치 (sudo 필요) ==="

# 1-2. Python pip + venv
echo "[1/4] apt update + 핵심 패키지 설치..."
sudo apt update -qq
sudo apt install -y python3-pip python3-venv ripgrep fd-find fzf unzip

# fd-find → fd 심볼릭 링크
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
  echo "[2/4] fd 심볼릭 링크 생성..."
  sudo ln -sf "$(which fdfind)" /usr/local/bin/fd
fi

# gh CLI 설치
echo "[3/4] GitHub CLI 설치..."
if ! command -v gh &>/dev/null; then
  (type -p wget >/dev/null || sudo apt install -y wget) \
    && sudo mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt update -qq \
    && sudo apt install -y gh
  echo "  gh 설치 완료: $(gh --version | head -1)"
else
  echo "  gh 이미 설치됨: $(gh --version | head -1)"
fi

# Python 패키지 (venv 없이 --break-system-packages)
echo "[4/4] Python 패키지 설치..."
pip3 install --break-system-packages anthropic ruff mypy 2>/dev/null || \
  pip3 install anthropic ruff mypy

echo ""
echo "=== Phase 1 완료 ==="
echo "확인:"
echo "  node: $(node --version 2>/dev/null || echo 'nvm install 22 필요')"
echo "  npm: $(npm --version 2>/dev/null || echo 'N/A')"
echo "  python3: $(python3 --version)"
echo "  rg: $(rg --version | head -1)"
echo "  fd: $(fd --version 2>/dev/null || fdfind --version 2>/dev/null)"
echo "  fzf: $(fzf --version)"
echo "  gh: $(gh --version | head -1)"
echo "  unzip: $(unzip -v | head -1)"
