#!/usr/bin/env bash
set -euo pipefail

step() { echo -e "\033[36m[INSTALL]\033[0m $*"; }
ok()   { echo -e "\033[32m[OK]\033[0m $*"; }
warn() { echo -e "\033[33m[WARN]\033[0m $*"; }

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR="${HOME}/.local/bin"

step "Creating ${TARGET_DIR}"
mkdir -p "${TARGET_DIR}"

step "Linking flutter-clean to ${TARGET_DIR}"
ln -sf "${REPO_DIR}/bin/flutter-clean" "${TARGET_DIR}/flutter-clean"

if ! command -v flutter-clean >/dev/null 2>&1; then
  # Try adding PATH to common shells
  for rc in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
    if [[ -f "$rc" ]] && ! grep -q 'export PATH=.*/.local/bin' "$rc"; then
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
      ok "Added ~/.local/bin to PATH in $(basename "$rc")"
    fi
  done
  # fish shell
  if [[ -d "$HOME/.config/fish" ]]; then
    if ! grep -q "fish_user_paths" "$HOME/.config/fish/config.fish" 2>/dev/null; then
      echo 'set -Ux fish_user_paths $HOME/.local/bin $fish_user_paths' >> "$HOME/.config/fish/config.fish" || true
      ok "Added ~/.local/bin to fish_user_paths"
    fi
  fi
  warn "Open a new terminal or 'source' your shell rc to pick up PATH."
else
  ok "flutter-clean is available in PATH"
fi

ok "Install complete. Use: flutter-clean --state bloc|riverpod|provider|getx --name \"My App\""

