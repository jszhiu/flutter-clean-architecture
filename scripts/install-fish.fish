#!/usr/bin/env fish
function step; set_color cyan; echo -n "[INSTALL] "; set_color normal; echo $argv; end
function ok; set_color green; echo -n "[OK] "; set_color normal; echo $argv; end
function warn; set_color yellow; echo -n "[WARN] "; set_color normal; echo $argv; end

set REPO_DIR (cd (dirname (status filename))/..; pwd)
set TARGET_DIR ~/.local/bin

step "Creating $TARGET_DIR"
mkdir -p $TARGET_DIR

step "Linking flutter-clean to $TARGET_DIR"
ln -sf $REPO_DIR/bin/flutter-clean $TARGET_DIR/flutter-clean

if not type -q flutter-clean
  set -Ux fish_user_paths $TARGET_DIR $fish_user_paths
  warn "fish_user_paths updated. Open a new shell to take effect."
else
  ok "flutter-clean is available in PATH"
end

ok "Install complete. Use: flutter-clean --state bloc|riverpod|provider|getx --name 'My App'"

