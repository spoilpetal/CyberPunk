#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

failed=0
pass() { printf 'PASS: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1" >&2; failed=1; }

while IFS= read -r -d '' script; do
    if /usr/bin/bash -n "$script"; then
        pass "Bash syntax: ${script#./}"
    else
        bad "Bash syntax: ${script#./}"
    fi
done < <(find scripts payload/home/.local/bin payload/home/.local/share/cyberpunk-theme -type f \
    \( -perm /111 -o -name '*.sh' \) -print0)

for script in scripts/install.sh scripts/restore.sh scripts/build-dependencies.sh; do
    if [[ -x "$script" ]]; then
        pass "Executable: $script"
    else
        bad "Executable: $script"
    fi
done
for script in scripts/install.sh scripts/restore.sh scripts/build-dependencies.sh scripts/verify.sh scripts/recovery-state.sh scripts/bashrc-integration.sh scripts/sddm-integration.sh; do
    if [[ "$(head -n 1 "$script")" == '#!/usr/bin/env bash' ]]; then
        pass "Shebang: $script"
    else
        bad "Shebang missing or misplaced: $script"
    fi
done

for file in packages/required.txt packages/official.txt packages/bundled.txt; do
    if [[ -s "$file" ]]; then
        pass "Manifest exists: $file"
    else
        bad "Manifest missing or empty: $file"
    fi
done

if [[ -s packages/required.txt && -s packages/official.txt && -s packages/bundled.txt ]] &&
   diff -q <(sort packages/required.txt) <(sort -u packages/required.txt) >/dev/null &&
   diff -q <(sort packages/official.txt) <(sort -u packages/official.txt) >/dev/null &&
   diff -q <(sort packages/bundled.txt) <(sort -u packages/bundled.txt) >/dev/null &&
   diff -q <(comm -23 <(sort packages/required.txt) <(sort packages/official.txt)) <(sort packages/bundled.txt) >/dev/null &&
   [[ -z "$(comm -12 <(sort packages/official.txt) <(sort packages/bundled.txt))" ]]; then
    pass 'Package manifests are unique, disjoint, and cover required.txt'
else
    bad 'Package manifest consistency'
fi

if [[ -f dist/dependencies/SHA256SUMS && ! -L dist/dependencies/SHA256SUMS ]] &&
   (cd dist/dependencies && sha256sum --check --strict SHA256SUMS); then
    pass 'Bundled dependency checksums'
else
    bad 'Bundled dependency checksums'
fi

for file in \
    payload/home/.config/waybar/wallust-colors.css \
    payload/home/.config/wofi/wallust-colors.css \
    payload/home/.local/share/cyberpunk-theme/kitty/wallust-colors.conf; do
    if [[ -f "$file" ]]; then
        pass "Wallust target staged: $file"
    else
        bad "Wallust target missing: $file"
    fi
done

if command -v jq >/dev/null 2>&1; then
    if jq empty payload/home/.config/waybar/config.jsonc; then
        pass 'Waybar configuration JSON syntax'
    else
        bad 'Waybar configuration JSON syntax'
    fi
else
    pass 'Waybar JSON syntax check skipped (jq is optional)'
fi

if grep -q 'target = .*\.config/waybar/wallust-colors.css' payload/home/.local/share/cyberpunk-theme/wallust/wallust.toml &&
   grep -q 'target = .*\.config/wofi/wallust-colors.css' payload/home/.local/share/cyberpunk-theme/wallust/wallust.toml &&
   grep -q 'WALLUST_DIR="\$THEME_DIR/wallust"' payload/home/.local/bin/cyberarch-wallpaper; then
    pass 'Wallpaper and Wallust paths are connected'
else
    bad 'Wallpaper and Wallust path integration'
fi

if [[ -d payload ]] && ! find payload -mindepth 1 ! -type d ! -type f -print -quit | grep -q .; then
    pass 'Payload contains only regular files and directories'
else
    bad 'Payload contains unsupported file types'
fi

for script in \
    payload/home/.local/bin/cyberarch-wallpaper \
    payload/home/.local/bin/cyberarch-random-wallpaper \
    payload/home/.local/bin/cyberarch-waybar-identity \
    payload/home/.local/bin/neochange \
    payload/home/.local/bin/cyberarch-screenshot \
    payload/home/.local/bin/cyberarch-start-dunst \
    payload/home/.local/bin/cyberarch-toggle-waybar \
    payload/home/.local/bin/cyberarch-exit-session \
    payload/home/.local/share/cyberpunk-theme/hypr/wallpaper-borders.sh; do
    if [[ -x "$script" ]]; then
        pass "Payload executable: $script"
    else
        bad "Payload script is not executable: $script"
    fi
done

if [[ -s scripts/recovery-state.sh ]] && grep -q 'INSTALL-STATE:' scripts/recovery-state.sh &&
   grep -q 'write_marker preparing' scripts/install.sh &&
   grep -q 'write_marker packages' scripts/install.sh &&
   grep -q 'write_marker deploying' scripts/install.sh &&
   grep -q 'required.txt' scripts/install.sh &&
   grep -q 'INSTALL-STATE' scripts/install.sh &&
   grep -q 'cyber_state_preflight' scripts/install.sh &&
   grep -q 'cyber_state_preflight' scripts/restore.sh &&
   grep -q 'DEPLOY-PROGRESS' scripts/recovery-state.sh &&
   grep -q 'RESTORE-PROGRESS' scripts/recovery-state.sh &&
   grep -q 'cyber_state_append_progress' scripts/install.sh &&
   grep -q 'cyber_bashrc_stage' scripts/install.sh &&
   grep -q 'pacman -Syu' scripts/install.sh &&
   grep -q 'LocalFileSigLevel' scripts/install.sh &&
   grep -q 'cyber_sddm_prompt_boot_enable' scripts/install.sh &&
   grep -q 'cyber_sddm_enable_at_boot' scripts/install.sh &&
   grep -q 'Enable SDDM at boot' scripts/sddm-integration.sh &&
   grep -q '\$THEME_DIR/hypr/wallpaper-borders.sh' payload/home/.local/bin/cyberarch-wallpaper &&
   ! grep -q 'cybershot hotkey' payload/home/.config/hypr/hyprland.lua &&
   grep -q 'cyberarch-start-dunst' payload/home/.config/hypr/hyprland.lua &&
   grep -q 'cyberarch-toggle-waybar' payload/home/.config/hypr/hyprland.lua &&
   grep -q 'cyberarch-exit-session' payload/home/.config/hypr/hyprland.lua &&
   grep -Fq 'hl.env("XDG_CURRENT_DESKTOP", "Hyprland")' payload/home/.config/hypr/hyprland.lua &&
   grep -q 'org.freedesktop.impl.portal.ScreenCast=hyprland' payload/home/.config/xdg-desktop-portal/portals.conf &&
   grep -q 'RECOVERY CONFLICT' scripts/recovery-state.sh; then
    pass 'Installer markers, manifest validation, and recovery checksum safeguards'
else
    bad 'Installer marker, manifest, or recovery checksum safeguards'
fi

if [[ -x tests/recovery-state-test.sh ]] && bash -n tests/recovery-state-test.sh && tests/recovery-state-test.sh; then
    pass 'Recovery-state conflict behavior tests'
else
    bad 'Recovery-state conflict behavior tests'
fi

if [[ -x tests/bashrc-integration-test.sh ]] && bash -n tests/bashrc-integration-test.sh && tests/bashrc-integration-test.sh; then
    pass 'Managed Bash integration tests'
else
    bad 'Managed Bash integration tests'
fi

if [[ -x tests/sddm-choice-test.sh ]] && bash -n tests/sddm-choice-test.sh && tests/sddm-choice-test.sh; then
    pass 'SDDM opt-in choice tests'
else
    bad 'SDDM opt-in choice tests'
fi

for doc in README.md docs/RESTORE.md docs/BUILD-DEPENDENCIES.md docs/SECURITY-REVIEW.md docs/REVIEW-REPORT.md docs/DESIGN-SYSTEM.md; do
    if [[ -s "$doc" ]]; then
        pass "Documentation: $doc"
    else
        bad "Documentation missing: $doc"
    fi
done

if find . -type f \( -name '*.new' -o -name '*.new.reviewed' \) -print -quit | grep -q .; then
    bad 'Obsolete candidate installer files remain'
else
    pass 'No obsolete candidate installer files'
fi

if grep -Il $'\r' scripts/*.sh tests/*.sh payload/home/.local/bin/* payload/home/.local/share/cyberpunk-theme/**/*.sh docs/*.md README.md | grep -q .; then
    bad 'Windows line endings detected'
else
    pass 'No Windows line endings in scripts and documentation'
fi

if ((failed == 0)); then
    printf '\nFINAL RESULT: ALL STATIC CHECKS PASSED\n'
else
    printf '\nFINAL RESULT: STATIC CHECKS FAILED\n' >&2
    exit 1
fi
