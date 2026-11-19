#!/usr/bin/env bash
# Shared validation and checksum helpers for protected Cyberpunk recovery.
# FILE-JOURNAL: kind|relative|existed(0|1)
# INSTALL-STATE: kind|relative|installed_sha256|original_sha256_or_ABSENT
# DEPLOY-PROGRESS: kind|relative|installed_sha256 (written only after verified deployment)
# RESTORE-PROGRESS: kind|relative|original_sha256_or_ABSENT (written after verified restoration)

cyber_state_error() {
    printf 'Recovery refused: %s\n' "$*" >&2
    return 1
}

cyber_state_validate_relative() {
    local relative="$1" component
    local -a components=()
    [[ -n "$relative" && "$relative" != /* && "$relative" != */ &&
       "$relative" != *//* && "$relative" != *'|'* &&
       "$relative" != *$'\t'* && "$relative" != *$'\n'* &&
       "$relative" != *$'\r'* ]] || return 1
    IFS='/' read -r -a components <<< "$relative"
    for component in "${components[@]}"; do
        [[ -n "$component" && "$component" != . && "$component" != .. ]] || return 1
    done
}

cyber_state_private_file() {
    local file="$1" owner mode links
    [[ -f "$file" && ! -L "$file" ]] || return 1
    read -r owner mode links < <(stat -c '%u %a %h' -- "$file") || return 1
    [[ "$owner" == "$EUID" && "$links" == 1 ]] || return 1
    (( (8#$mode & 077) == 0 )) || return 1
}

cyber_state_private_dir() {
    local dir="$1" owner mode
    [[ -d "$dir" && ! -L "$dir" ]] || return 1
    read -r owner mode < <(stat -c '%u %a' -- "$dir") || return 1
    [[ "$owner" == "$EUID" ]] || return 1
    (( (8#$mode & 077) == 0 )) || return 1
}

cyber_state_target_path_safe() {
    local kind="$1" relative="$2" target parent privileged=no
    cyber_state_validate_relative "$relative" || return 1
    if [[ "$kind" == U ]]; then
        target="$HOME/$relative"
    elif [[ "$kind" == S ]]; then
        target="/usr/$relative"
        privileged=yes
    else
        return 1
    fi

    if [[ "$privileged" == yes ]]; then
        sudo /usr/bin/test ! -L "$target" || return 1
        if sudo /usr/bin/test -e "$target"; then
            sudo /usr/bin/test -f "$target" || return 1
        fi
    else
        [[ ! -L "$target" ]] || return 1
        if [[ -e "$target" ]]; then [[ -f "$target" ]] || return 1; fi
    fi

    parent="$(dirname -- "$target")"
    while [[ "$parent" != / && "$parent" != . ]]; do
        if [[ "$privileged" == yes ]]; then
            sudo /usr/bin/test ! -L "$parent" || return 1
            if sudo /usr/bin/test -e "$parent"; then
                sudo /usr/bin/test -d "$parent" || return 1
            fi
        else
            [[ ! -L "$parent" ]] || return 1
            if [[ -e "$parent" ]]; then [[ -d "$parent" ]] || return 1; fi
        fi
        parent="$(dirname -- "$parent")"
    done
    printf '%s\n' "$target"
}

cyber_state_hash_target() {
    local kind="$1" relative="$2" target
    target="$(cyber_state_target_path_safe "$kind" "$relative")" || return 1
    if [[ "$kind" == S ]]; then
        if sudo /usr/bin/test -e "$target"; then
            sudo sha256sum -- "$target" | awk '{print $1}'
        else
            printf 'ABSENT\n'
        fi
    else
        if [[ -e "$target" ]]; then
            sha256sum -- "$target" | awk '{print $1}'
        else
            printf 'ABSENT\n'
        fi
    fi
}

cyber_state_backup_hash() {
    local kind="$1" relative="$2" base="$3" backup parent component
    local -a components=()
    cyber_state_validate_relative "$relative" || return 1
    if [[ "$kind" == U ]]; then
        base="$base/home"
        backup="$base/$relative"
        [[ -d "$base" && ! -L "$base" ]] || return 1
        parent="$base"
        if [[ "$relative" == */* ]]; then IFS='/' read -r -a components <<< "${relative%/*}"; fi
        for component in "${components[@]}"; do
            parent="$parent/$component"
            [[ -d "$parent" && ! -L "$parent" ]] || return 1
        done
        [[ -f "$backup" && ! -L "$backup" ]] || return 1
        sha256sum -- "$backup" | awk '{print $1}'
    elif [[ "$kind" == S ]]; then
        base="$base/system"
        backup="$base/$relative"
        sudo /usr/bin/test -d "$base" && sudo /usr/bin/test ! -L "$base" || return 1
        parent="$base"
        if [[ "$relative" == */* ]]; then IFS='/' read -r -a components <<< "${relative%/*}"; fi
        for component in "${components[@]}"; do
            parent="$parent/$component"
            sudo /usr/bin/test -d "$parent" && sudo /usr/bin/test ! -L "$parent" || return 1
        done
        sudo /usr/bin/test -f "$backup" && sudo /usr/bin/test ! -L "$backup" || return 1
        sudo sha256sum -- "$backup" | awk '{print $1}'
    else
        return 1
    fi
}

cyber_state_backup_absent() {
    local kind="$1" relative="$2" base="$3" root path parent component privileged=no
    local -a components=()
    cyber_state_validate_relative "$relative" || return 1
    if [[ "$kind" == U ]]; then
        root="$base/home"
    elif [[ "$kind" == S ]]; then
        root="$base/system"
        privileged=yes
    else
        return 1
    fi

    if [[ "$privileged" == yes ]]; then
        sudo /usr/bin/test -d "$root" && sudo /usr/bin/test ! -L "$root" || return 1
    else
        [[ -d "$root" && ! -L "$root" ]] || return 1
    fi

    parent="$root"
    if [[ "$relative" == */* ]]; then IFS='/' read -r -a components <<< "${relative%/*}"; fi
    for component in "${components[@]}"; do
        parent="$parent/$component"
        if [[ "$privileged" == yes ]]; then
            if sudo /usr/bin/test -e "$parent" || sudo /usr/bin/test -L "$parent"; then
                sudo /usr/bin/test -d "$parent" && sudo /usr/bin/test ! -L "$parent" || return 1
            else
                break
            fi
        else
            if [[ -e "$parent" || -L "$parent" ]]; then
                [[ -d "$parent" && ! -L "$parent" ]] || return 1
            else
                break
            fi
        fi
    done

    path="$root/$relative"
    if [[ "$privileged" == yes ]]; then
        ! sudo /usr/bin/test -e "$path" && ! sudo /usr/bin/test -L "$path"
    else
        [[ ! -e "$path" && ! -L "$path" ]]
    fi
}

cyber_state_lookup() {
    local state_file="$1" wanted_kind="$2" wanted_relative="$3"
    local kind relative installed original
    while IFS='|' read -r kind relative installed original || [[ -n "${kind:-}" ]]; do
        if [[ "$kind" == "$wanted_kind" && "$relative" == "$wanted_relative" ]]; then
            printf '%s|%s\n' "$installed" "$original"
            return 0
        fi
    done < "$state_file"
    return 1
}

cyber_state_append_progress() {
    local file="$1" kind="$2" relative="$3" value="$4"
    printf '%s|%s|%s\n' "$kind" "$relative" "$value" >> "$file" || return 1
    sync -f "$file" || return 1
}

cyber_state_preflight() {
    local state_file="$1" journal="$2" backup_root="$3" deploy_file="$4" restore_file="$5"
    local line kind relative existed installed original key current backup_hash target conflict=0
    local -A journal_existed=() state_installed=() state_original=() deployed=() restored=()
    local -a journal_keys=()

    cyber_state_private_dir "$backup_root" || cyber_state_error "backup directory is not private, user-owned, or a real directory: $backup_root" || return 1
    cyber_state_private_file "$journal" || cyber_state_error 'FILE-JOURNAL is missing, unsafe, or has incorrect ownership/permissions.' || return 1
    cyber_state_private_file "$state_file" || cyber_state_error 'INSTALL-STATE is missing, unsafe, or has incorrect ownership/permissions. Legacy backups are not eligible for protected apply.' || return 1
    cyber_state_private_file "$deploy_file" || cyber_state_error 'DEPLOY-PROGRESS is missing, unsafe, or has incorrect ownership/permissions.' || return 1
    cyber_state_private_file "$restore_file" || cyber_state_error 'RESTORE-PROGRESS is missing, unsafe, or has incorrect ownership/permissions.' || return 1

    # Parse the journal first; it is the authoritative list of managed destinations.
    while IFS='|' read -r kind relative existed || [[ -n "${kind:-}" ]]; do
        [[ "$kind" =~ ^(U|S)$ && "$existed" =~ ^[01]$ ]] || { cyber_state_error 'malformed FILE-JOURNAL entry.'; return 1; }
        cyber_state_validate_relative "$relative" || { cyber_state_error "unsafe journal path: $relative"; return 1; }
        key="$kind|$relative"
        [[ -z "${journal_existed[$key]+x}" ]] || { cyber_state_error "duplicate journal entry: $key"; return 1; }
        journal_existed["$key"]="$existed"
        journal_keys+=("$key")
    done < "$journal"
    ((${#journal_keys[@]} > 0)) || { cyber_state_error 'FILE-JOURNAL is empty.'; return 1; }

    while IFS='|' read -r kind relative installed original || [[ -n "${kind:-}" ]]; do
        [[ "$kind" =~ ^(U|S)$ && "$installed" =~ ^[a-fA-F0-9]{64}$ &&
           ( "$original" == ABSENT || "$original" =~ ^[a-fA-F0-9]{64}$ ) ]] || {
            cyber_state_error 'malformed INSTALL-STATE entry.'; return 1;
        }
        cyber_state_validate_relative "$relative" || { cyber_state_error "unsafe state path: $relative"; return 1; }
        key="$kind|$relative"
        [[ -n "${journal_existed[$key]+x}" ]] || { cyber_state_error "state contains an entry absent from FILE-JOURNAL: $key"; return 1; }
        [[ -z "${state_installed[$key]+x}" ]] || { cyber_state_error "duplicate INSTALL-STATE entry: $key"; return 1; }
        if [[ "${journal_existed[$key]}" == 0 && "$original" != ABSENT ]] ||
           [[ "${journal_existed[$key]}" == 1 && "$original" == ABSENT ]]; then
            cyber_state_error "original-state flag disagrees with FILE-JOURNAL: $key"; return 1
        fi
        state_installed["$key"]="${installed,,}"
        state_original["$key"]="${original^^}"
    done < "$state_file"

    ((${#state_installed[@]} == ${#journal_existed[@]})) || { cyber_state_error 'INSTALL-STATE does not exactly cover FILE-JOURNAL.'; return 1; }

    # Verify every recorded original backup against its state checksum.
    for key in "${journal_keys[@]}"; do
        kind="${key%%|*}"; relative="${key#*|}"; original="${state_original[$key]}"
        if [[ "$original" == ABSENT ]]; then
            cyber_state_backup_absent "$kind" "$relative" "$backup_root" || {
                cyber_state_error "unexpected backup exists for originally absent file: $key"; return 1;
            }
        else
            backup_hash="$(cyber_state_backup_hash "$kind" "$relative" "$backup_root")" || {
                cyber_state_error "missing or unsafe original backup: $key"; return 1;
            }
            [[ "${backup_hash,,}" == "${original,,}" ]] || {
                cyber_state_error "original backup checksum mismatch: $key"; return 1;
            }
        fi
    done

    # Validate deployment progress. Only a completed, checksum-verified copy may be undone.
    while IFS='|' read -r kind relative installed || [[ -n "${kind:-}" ]]; do
        [[ "$kind" =~ ^(U|S)$ && "$installed" =~ ^[a-fA-F0-9]{64}$ ]] || { cyber_state_error 'malformed DEPLOY-PROGRESS entry.'; return 1; }
        cyber_state_validate_relative "$relative" || { cyber_state_error "unsafe deployment progress path: $relative"; return 1; }
        key="$kind|$relative"
        [[ -n "${state_installed[$key]+x}" ]] || { cyber_state_error "DEPLOY-PROGRESS has an unknown entry: $key"; return 1; }
        [[ "${state_installed[$key]}" == "${installed,,}" ]] || { cyber_state_error "DEPLOY-PROGRESS checksum disagrees with INSTALL-STATE: $key"; return 1; }
        [[ -z "${deployed[$key]+x}" ]] || { cyber_state_error "duplicate DEPLOY-PROGRESS entry: $key"; return 1; }
        deployed["$key"]=1
    done < "$deploy_file"

    # Validate restoration progress and ensure previously restored files remain original.
    while IFS='|' read -r kind relative original || [[ -n "${kind:-}" ]]; do
        [[ "$kind" =~ ^(U|S)$ && ( "$original" == ABSENT || "$original" =~ ^[a-fA-F0-9]{64}$ ) ]] || {
            cyber_state_error 'malformed RESTORE-PROGRESS entry.'; return 1;
        }
        cyber_state_validate_relative "$relative" || { cyber_state_error "unsafe restoration progress path: $relative"; return 1; }
        key="$kind|$relative"
        [[ -n "${state_original[$key]+x}" ]] || { cyber_state_error "RESTORE-PROGRESS has an unknown entry: $key"; return 1; }
        [[ "${state_original[$key]}" == "${original^^}" ]] || { cyber_state_error "RESTORE-PROGRESS checksum disagrees with INSTALL-STATE: $key"; return 1; }
        [[ -z "${restored[$key]+x}" ]] || { cyber_state_error "duplicate RESTORE-PROGRESS entry: $key"; return 1; }
        restored["$key"]=1
    done < "$restore_file"

    # Full conflict preflight. No destination may be changed until every entry passes.
    for key in "${journal_keys[@]}"; do
        kind="${key%%|*}"; relative="${key#*|}"
        current="$(cyber_state_hash_target "$kind" "$relative")" || {
            cyber_state_error "unsafe destination path: $key"; return 1;
        }
        original="${state_original[$key]}"; installed="${state_installed[$key]}"
        if [[ -n "${restored[$key]+x}" ]]; then
            if [[ "${current^^}" != "$original" ]]; then
                printf 'RECOVERY CONFLICT: %s (previously restored, now changed)\n' "$key" >&2
                conflict=1
            fi
        elif [[ "${current^^}" == "$original" ]]; then
            : # Already original, or never deployed.
        elif [[ "${current,,}" == "$installed" && ( -n "${deployed[$key]+x}" || "$installed" == "$original" ) ]]; then
            : # Verified deployment; safe to restore.
        else
            target="$HOME/$relative"; [[ "$kind" == S ]] && target="/usr/$relative"
            printf 'RECOVERY CONFLICT: %s (current state is neither verified installed nor original)\n' "$target" >&2
            conflict=1
        fi
    done
    ((conflict == 0)) || { cyber_state_error 'conflicts found; no files were changed. Resolve them separately before retrying.'; return 1; }
    return 0
}
