#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PROJECT_DIR/scripts/sddm-integration.sh"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

if printf 'yes\n' | { cyber_sddm_prompt_boot_enable; [[ "$CYBER_SDDM_BOOT_ENABLE" == 1 ]]; }; then
    pass 'SDDM yes choice requests boot enablement'
else
    fail 'SDDM yes choice'
fi

if printf 'n\n' | { cyber_sddm_prompt_boot_enable; [[ "$CYBER_SDDM_BOOT_ENABLE" == 0 ]]; }; then
    pass 'SDDM no choice leaves service unchanged'
else
    fail 'SDDM no choice'
fi

if printf '\n' | { cyber_sddm_prompt_boot_enable; [[ "$CYBER_SDDM_BOOT_ENABLE" == 0 ]]; }; then
    pass 'SDDM empty choice defaults to No'
else
    fail 'SDDM empty choice'
fi

if printf 'maybe\n' | cyber_sddm_prompt_boot_enable >/dev/null 2>&1; then
    fail 'Invalid SDDM choice was accepted'
else
    pass 'Invalid SDDM choice is rejected'
fi

if ! grep -Fq 'sudo systemctl enable sddm.service' "$PROJECT_DIR/scripts/sddm-integration.sh"; then
    fail 'SDDM enable action is missing'
fi
if grep -Eq 'systemctl (start|restart|disable) sddm' "$PROJECT_DIR/scripts/sddm-integration.sh"; then
    fail 'SDDM helper unexpectedly starts, restarts, or disables the service'
fi
pass 'SDDM helper only enables boot service when explicitly selected'
