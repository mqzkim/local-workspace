#!/usr/bin/env bash
# WSL Claude Code 풀 마이그레이션 (sudo 불필요한 Phase 2~9)
# 사전 조건: Phase 1 (wsl-migrate-phase1-sudo.sh) 완료
set -euo pipefail

HOME_DIR="/home/mqz"
WIN_HOME="/mnt/c/Users/USER"
WIN_WORKSPACE="/mnt/c/workspace"
WSL_WORKSPACE="$HOME_DIR/workspace"
CLAUDE_DIR="$HOME_DIR/.claude"

echo "============================================"
echo "  WSL Claude Code 풀 마이그레이션"
echo "============================================"

# ─── Phase 2: Claude Code 설치 ───
echo ""
echo "=== Phase 2: Claude Code CLI 설치 ==="
if ! command -v claude &>/dev/null; then
  npm install -g @anthropic-ai/claude-code
  echo "  Claude Code 설치 완료: $(claude --version 2>/dev/null || echo 'installed')"
else
  echo "  Claude Code 이미 설치됨: $(claude --version 2>/dev/null)"
fi

# ─── Phase 3: settings.json 경로 치환 ───
echo ""
echo "=== Phase 3: settings.json 마이그레이션 ==="

# 3-1. 전역 settings.json
mkdir -p "$CLAUDE_DIR"
cp "$WIN_HOME/.claude/settings.json" "$CLAUDE_DIR/settings.json"

# 경로 치환: C:/workspace → /home/mqz/workspace, C:/Users/USER → /home/mqz
sed -i 's|C:/workspace|/home/mqz/workspace|g' "$CLAUDE_DIR/settings.json"
sed -i 's|C:/Users/USER|/home/mqz|g' "$CLAUDE_DIR/settings.json"
# bash 경로도 치환 (Git Bash /c/ 형태)
sed -i 's|/c/workspace|/home/mqz/workspace|g' "$CLAUDE_DIR/settings.json"
sed -i 's|/c/Users/USER|/home/mqz|g' "$CLAUDE_DIR/settings.json"
echo "  전역 settings.json 치환 완료"

# ─── Phase 4: Hub 시스템 마이그레이션 ───
echo ""
echo "=== Phase 4: Hub 시스템 마이그레이션 ==="

# 4-1. hub.config.json 복사 + 치환
HUB_DIR="$WSL_WORKSPACE/.claude/hub"
if [ -d "$HUB_DIR" ]; then
  # hub.config.json
  if [ -f "$HUB_DIR/hub.config.json" ]; then
    sed -i 's|C:/workspace|/home/mqz/workspace|g' "$HUB_DIR/hub.config.json"
    sed -i 's|C:/Users/USER|/home/mqz|g' "$HUB_DIR/hub.config.json"
    echo "  hub.config.json 치환 완료"
  fi

  # registry.json
  if [ -f "$HUB_DIR/registry.json" ]; then
    sed -i 's|C:/workspace|/home/mqz/workspace|g' "$HUB_DIR/registry.json"
    sed -i 's|C:/Users/USER|/home/mqz|g' "$HUB_DIR/registry.json"
    echo "  registry.json 치환 완료"
  fi

  # 4-2. claude-hub-lib.sh
  if [ -f "$HUB_DIR/scripts/claude-hub-lib.sh" ]; then
    sed -i 's|HUB_ROOT="/c/workspace/.claude/hub"|HUB_ROOT="/home/mqz/workspace/.claude/hub"|' "$HUB_DIR/scripts/claude-hub-lib.sh"
    sed -i 's|HUB_ROOT_WIN="C:/workspace/.claude/hub"|HUB_ROOT_WIN="/home/mqz/workspace/.claude/hub"|' "$HUB_DIR/scripts/claude-hub-lib.sh"
    echo "  claude-hub-lib.sh 치환 완료"
  fi

  # 4-3. JS 스크립트 4개 — fallback 경로만 치환 (CLAUDE_HUB_ROOT 환경변수 우선)
  for jsfile in sync.js scan.js init.js status.js; do
    if [ -f "$HUB_DIR/scripts/$jsfile" ]; then
      sed -i 's|"C:/workspace/.claude/hub"|"/home/mqz/workspace/.claude/hub"|g' "$HUB_DIR/scripts/$jsfile"
      echo "  $jsfile 치환 완료"
    fi
  done

  echo "  Hub 시스템 마이그레이션 완료"
else
  echo "  [SKIP] Hub 디렉토리 없음 (git clone 후 재실행 필요)"
fi

# ─── Phase 5: GSD 시스템 ───
echo ""
echo "=== Phase 5: GSD 시스템 ==="

# 5-1. GSD 설치
if ! command -v gsd &>/dev/null; then
  npm install -g get-shit-done-cc
  echo "  GSD 설치 완료"
else
  echo "  GSD 이미 설치됨"
fi

# 5-2. GSD Hook 파일 복사
mkdir -p "$CLAUDE_DIR/hooks"
if [ -d "$WIN_HOME/.claude/hooks" ]; then
  cp "$WIN_HOME/.claude/hooks"/gsd-*.js "$CLAUDE_DIR/hooks/" 2>/dev/null && \
    echo "  GSD hooks 복사 완료" || echo "  [SKIP] GSD hook 파일 없음"
fi

# ─── Phase 6: Skills / Agents / Commands 복사 ───
echo ""
echo "=== Phase 6: 전역 에셋 복사 ==="

# 6-2. 전역 Skills
if [ -d "$WIN_HOME/.claude/skills" ]; then
  mkdir -p "$CLAUDE_DIR/skills"
  cp -r "$WIN_HOME/.claude/skills/"* "$CLAUDE_DIR/skills/" 2>/dev/null
  echo "  전역 Skills 복사 완료 ($(ls "$CLAUDE_DIR/skills/" | wc -l) 디렉토리)"
fi

# 6-3. 메모리 파일
if [ -d "$WIN_HOME/.claude/projects" ]; then
  # 기존 프로젝트 메모리가 있으면 보존, 없으면 복사
  for proj_dir in "$WIN_HOME/.claude/projects/"*/; do
    dir_name=$(basename "$proj_dir")
    target="$CLAUDE_DIR/projects/$dir_name"
    if [ ! -d "$target" ]; then
      mkdir -p "$target"
      cp -r "$proj_dir"* "$target/" 2>/dev/null
      echo "  프로젝트 메모리 복사: $dir_name"
    else
      echo "  프로젝트 메모리 이미 존재: $dir_name (건너뜀)"
    fi
  done
fi

# 6-4. output-styles 복사
if [ -d "$WIN_HOME/.claude/output-styles" ]; then
  mkdir -p "$CLAUDE_DIR/output-styles"
  cp -r "$WIN_HOME/.claude/output-styles/"* "$CLAUDE_DIR/output-styles/" 2>/dev/null
  echo "  output-styles 복사 완료"
fi

# ─── Phase 7: Playwright 브라우저 (MCP는 자동) ───
echo ""
echo "=== Phase 7: MCP / Playwright ==="
echo "  MCP 플러그인은 Claude Code 첫 실행 시 자동 설치됩니다."
echo "  Playwright 브라우저는 필요 시 수동 설치: npx playwright install --with-deps chromium"

# ─── Phase 8: Neovim + tmux ───
echo ""
echo "=== Phase 8: Neovim LazyVim + tmux ==="

# 8-1. LazyVim
if [ ! -d "$HOME_DIR/.config/nvim" ]; then
  git clone https://github.com/LazyVim/starter "$HOME_DIR/.config/nvim"
  rm -rf "$HOME_DIR/.config/nvim/.git"
  echo "  LazyVim 설치 완료"
else
  echo "  LazyVim 이미 설치됨"
fi

# 8-2. tmux TPM
if [ ! -d "$HOME_DIR/.tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm "$HOME_DIR/.tmux/plugins/tpm"
  echo "  tmux TPM 설치 완료"
else
  echo "  tmux TPM 이미 설치됨"
fi

# 8-3. tmux.conf
if [ ! -f "$HOME_DIR/.tmux.conf" ]; then
  cat > "$HOME_DIR/.tmux.conf" << 'TMUXEOF'
# Prefix: Ctrl+a
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Mouse
set -g mouse on

# Terminal
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"

# Start index at 1
set -g base-index 1
setw -g pane-base-index 1

# Vim keybindings for pane navigation
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Split with | and -
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# Reload config
bind r source-file ~/.tmux.conf \; display "Config reloaded"

# History
set -g history-limit 50000

# Escape time (for nvim)
set -sg escape-time 0

# Catppuccin theme
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'catppuccin/tmux'
set -g @catppuccin_flavor 'mocha'

# Status bar
set -g status-position top

# Initialize TPM (must be last)
run '~/.tmux/plugins/tpm/tpm'
TMUXEOF
  echo "  tmux.conf 생성 완료"
else
  echo "  tmux.conf 이미 존재"
fi

# ─── Phase 9: 환경변수 + 셸 설정 ───
echo ""
echo "=== Phase 9: 환경변수 및 셸 설정 ==="

# bashrc에 추가 (중복 방지)
MARKER="# === WSL Claude Code Environment ==="
if ! grep -q "$MARKER" "$HOME_DIR/.bashrc"; then
  cat >> "$HOME_DIR/.bashrc" << 'BASHEOF'

# === WSL Claude Code Environment ===
export CLAUDE_HUB_ROOT="$HOME/workspace/.claude/hub"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# Workspace alias
alias ws='cd ~/workspace'
alias cc='claude'

# fd alias (Ubuntu names it fdfind)
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
  alias fd='fdfind'
fi
# === END Claude Code Environment ===
BASHEOF
  echo "  .bashrc 환경변수 추가 완료"
else
  echo "  .bashrc 이미 설정됨"
fi

# ─── 완료 요약 ───
echo ""
echo "============================================"
echo "  마이그레이션 완료!"
echo "============================================"
echo ""
echo "다음 단계:"
echo "  1. source ~/.bashrc"
echo "  2. claude login  (인증)"
echo "  3. cd ~/workspace && claude  (테스트)"
echo ""
echo "워크스페이스 설정:"
echo "  git clone https://github.com/mqzkim/workspace.git ~/workspace"
echo "  (또는 기존 Windows 워크스페이스에서 복사)"
echo ""
echo "Playwright 브라우저 (필요 시):"
echo "  npx playwright install --with-deps chromium"
echo ""
echo "tmux 플러그인 설치:"
echo "  tmux → prefix + I (Ctrl+a, I)"
