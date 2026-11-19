#!/usr/bin/env bash

# Interactive, opt-in SDDM boot enablement. This helper never starts or
# disables SDDM; a negative answer leaves the current service state untouched.
cyber_sddm_prompt_boot_enable() {
    local answer
    if ! read -r -p 'Enable SDDM at boot? [y/N]: ' answer; then
        printf 'No answer received for the SDDM choice.\n' >&2
        return 1
    fi

    case "${answer,,}" in
        y|yes)
            CYBER_SDDM_BOOT_ENABLE=1
            ;;
        n|no|'')
            CYBER_SDDM_BOOT_ENABLE=0
            ;;
        *)
            printf 'Invalid SDDM choice. Enter y/yes or n/no. No changes made.\n' >&2
            return 1
            ;;
    esac
}

cyber_sddm_enable_at_boot() {
    sudo systemctl enable sddm.service
}
