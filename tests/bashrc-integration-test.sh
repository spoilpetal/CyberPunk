#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/bashrc-integration.sh"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
BEGIN='# >>> Cyberpunk Desktop Installer managed block >>>'
END='# <<< Cyberpunk Desktop Installer managed block <<<'
SOURCE='.local/share/cyberpunk-theme/shell/cyberpunk-prompt.sh'

# Existing content and aliases remain intact.
printf '# user config\nalias ll="ls -lah"\n' > "$TMP/.bashrc"
cyber_bashrc_stage "$TMP/.bashrc" "$TMP/staged" "$TMP/base" "$BEGIN" "$END" "$SOURCE"
grep -Fqx '# user config' "$TMP/staged"
grep -Fqx 'alias ll="ls -lah"' "$TMP/staged"
grep -Fqx "$BEGIN" "$TMP/staged"
grep -Fqx "$END" "$TMP/staged"
grep -Fqx '    source "$HOME/.local/share/cyberpunk-theme/shell/cyberpunk-prompt.sh"' "$TMP/staged"
printf 'PASS: existing .bashrc content preserved and managed prompt block added\n'

# Existing managed block is replaced, not duplicated.
cp "$TMP/staged" "$TMP/.bashrc"
printf '# >>> old block content >>>\n' >> "$TMP/.bashrc"
cyber_bashrc_stage "$TMP/.bashrc" "$TMP/staged2" "$TMP/base2" "$BEGIN" "$END" "$SOURCE"
[[ "$(grep -Fxc "$BEGIN" "$TMP/staged2")" == 1 ]]
! grep -Fq '# >>> old block content >>>' "$TMP/staged2"
printf 'PASS: existing managed block updated without duplication\n'

# Incomplete marker state must be rejected.
printf '# >>> Cyberpunk Desktop Installer managed block >>>\n' > "$TMP/bad.bashrc"
if cyber_bashrc_validate "$TMP/bad.bashrc" "$BEGIN" "$END" >/dev/null 2>&1; then
    printf 'FAIL: incomplete managed block accepted\n' >&2; exit 1
fi
printf 'PASS: incomplete managed block rejected\n'

# Missing .bashrc is created with only the managed block.
cyber_bashrc_stage "$TMP/missing.bashrc" "$TMP/new.bashrc" "$TMP/new.base" "$BEGIN" "$END" "$SOURCE"
grep -Fqx "$BEGIN" "$TMP/new.bashrc"
grep -Fqx "$END" "$TMP/new.bashrc"
printf 'PASS: fresh-user .bashrc generated safely\n'

printf 'ALL BASHRC INTEGRATION TESTS PASSED\n'
