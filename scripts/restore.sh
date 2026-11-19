#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

STATE_DIR="$HOME/.local/state/cyberpunk-desktop-installer"
BACKUPS_DIR="$STATE_DIR/backups"
LATEST_FILE="$STATE_DIR/latest-backup"
INSTALL_STATE=""
DEPLOY_PROGRESS=""
RESTORE_PROGRESS=""
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PROJECT_DIR/scripts/recovery-state.sh"

MODE=plan
SELECTED_BACKUP=""

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

usage() {
    printf 'Usage: %s [--plan|--apply|--clear-marker] [BACKUP_DIRECTORY]\n' "${0##*/}"
    printf 'Default: inspect the interrupted installation or latest successful backup.\n'
    printf '  --clear-marker  Clear a preparing/packages marker and generated staging files only.\n'
}

while (($#)); do
    case "$1" in
        --plan) MODE=plan ;;
        --apply) MODE=apply ;;
        --clear-marker) MODE=clear-marker ;;
        --help|-h) usage; exit 0 ;;
        --*) usage >&2; fail "Unknown option: $1" ;;
        *)
            [[ -z "$SELECTED_BACKUP" ]] ||
                fail 'Only one backup directory may be supplied.'
            SELECTED_BACKUP="$1"
            ;;
    esac
    shift
done

[[ $EUID -ne 0 ]] || fail 'Run as the normal desktop user, not root.'
[[ "$HOME" == /* && "$HOME" != / ]] || fail 'Invalid home directory.'

[[ -d "$STATE_DIR" && ! -L "$STATE_DIR" ]] ||
    fail "Installer state directory not found or is a symlink: $STATE_DIR"

[[ -d "$BACKUPS_DIR" && ! -L "$BACKUPS_DIR" ]] ||
    fail "Backup directory not found or is a symlink: $BACKUPS_DIR"

if [[ "$MODE" == apply || "$MODE" == clear-marker ]]; then
    command -v flock >/dev/null 2>&1 || fail "Required command not found: flock"
    cyber_state_private_dir "$STATE_DIR" || fail "Installer state directory is not private and user-owned: $STATE_DIR"
    cyber_state_private_dir "$BACKUPS_DIR" || fail "Installer backups directory is not private and user-owned: $BACKUPS_DIR"
    [[ ! -L "$STATE_DIR/operation.lock" ]] ||
        fail "Refusing a symlinked operation lock."
    [[ ! -e "$STATE_DIR/operation.lock" || -f "$STATE_DIR/operation.lock" ]] ||
        fail "Installer operation lock is not a regular file."
    exec 9>>"$STATE_DIR/operation.lock"
    cyber_state_private_file "$STATE_DIR/operation.lock" || fail "Installer operation lock has unsafe ownership or permissions."
    flock -n 9 || fail "Another installer or recovery operation is already running."
fi

for tool in realpath find sudo stat sha256sum awk sync grep mktemp; do
    command -v "$tool" >/dev/null 2>&1 ||
        fail "Required command not found: $tool"
done

BACKUPS_REAL="$(realpath -e -- "$BACKUPS_DIR")"

if [[ -n "$SELECTED_BACKUP" ]]; then
    [[ ! -L "$SELECTED_BACKUP" ]] ||
        fail 'Refusing a symlink as the selected backup.'
    [[ -d "$SELECTED_BACKUP" ]] ||
        fail 'Selected backup directory does not exist.'
    BACKUP_ROOT="$(realpath -e -- "$SELECTED_BACKUP")"
else
    mapfile -d '' INTERRUPTED_MARKERS < <(
        find "$BACKUPS_REAL" -mindepth 2 -maxdepth 2 \
            -type f -name INSTALL-IN-PROGRESS -print0
    )

    if ((${#INTERRUPTED_MARKERS[@]} > 1)); then
        printf 'More than one interrupted installation was found:\n' >&2
        printf '  %s\n' "${INTERRUPTED_MARKERS[@]%/INSTALL-IN-PROGRESS}" >&2
        fail 'Select the intended backup directory explicitly.'
    elif ((${#INTERRUPTED_MARKERS[@]} == 1)); then
        BACKUP_ROOT="$(dirname -- "${INTERRUPTED_MARKERS[0]}")"
    else
        cyber_state_private_file "$LATEST_FILE" ||
            fail 'No safe latest-backup record was found.'

        mapfile -t LATEST_LINES < "$LATEST_FILE"
        ((${#LATEST_LINES[@]} == 1)) ||
            fail 'Latest-backup record has an invalid format.'

        SELECTED_BACKUP="${LATEST_LINES[0]}"
        [[ -n "$SELECTED_BACKUP" ]] ||
            fail 'Latest-backup record is empty.'
        [[ ! -L "$SELECTED_BACKUP" && -d "$SELECTED_BACKUP" ]] ||
            fail 'Latest backup directory is missing or invalid.'

        BACKUP_ROOT="$(realpath -e -- "$SELECTED_BACKUP")"
    fi
fi

[[ "$(dirname -- "$BACKUP_ROOT")" == "$BACKUPS_REAL" ]] ||
    fail 'Selected backup is not a direct child of the installer backup directory.'

BACKUP_NAME="${BACKUP_ROOT##*/}"
[[ "$BACKUP_NAME" =~ ^[0-9]{8}-[0-9]{6}$ ]] ||
    fail 'Backup directory name does not match the expected timestamp format.'

JOURNAL="$BACKUP_ROOT/FILE-JOURNAL"
MARKER="$BACKUP_ROOT/INSTALL-IN-PROGRESS"
INSTALL_STATE="$BACKUP_ROOT/INSTALL-STATE"
DEPLOY_PROGRESS="$BACKUP_ROOT/DEPLOY-PROGRESS"
RESTORE_PROGRESS="$BACKUP_ROOT/RESTORE-PROGRESS"

[[ -f "$JOURNAL" && ! -L "$JOURNAL" ]] ||
    fail 'Backup journal is missing or invalid.'

PHASE=completed

if [[ -e "$MARKER" ]]; then
    [[ -f "$MARKER" && ! -L "$MARKER" ]] ||
        fail 'Installation marker is not a regular file.'
    if [[ "$MODE" == apply || "$MODE" == clear-marker ]]; then
        cyber_state_private_file "$MARKER" || fail 'Installation marker has unsafe ownership or permissions.'
    fi

    mapfile -t MARKER_LINES < "$MARKER"
    ((${#MARKER_LINES[@]} == 2)) ||
        fail 'Installation marker has an invalid format.'

    [[ "${MARKER_LINES[0]}" =~ ^phase=(preparing|packages|deploying)$ ]] ||
        fail 'Installation marker contains an invalid phase.'

    [[ "${MARKER_LINES[1]}" == "backup=$BACKUP_ROOT" ]] ||
        fail 'Installation marker points to a different backup.'

    PHASE="${MARKER_LINES[0]#phase=}"
fi

if [[ "$MODE" == clear-marker ]]; then
    cyber_state_private_dir "$BACKUP_ROOT" || fail 'Selected backup directory is not private and user-owned.'
    cyber_state_private_file "$MARKER" || fail 'Installation marker has unsafe ownership or permissions.'
    [[ -f "$MARKER" && ! -L "$MARKER" ]] ||
        fail "No valid installation marker exists to clear."
    [[ "$PHASE" == preparing || "$PHASE" == packages ]] ||
        fail "Only preparing/packages markers may be cleared; current phase is $PHASE."

    printf "Backup: %s\n" "$BACKUP_ROOT"
    printf "Phase: %s\n" "$PHASE"
    printf "This removes INSTALL-IN-PROGRESS and generated temporary staging files only. FILE-JOURNAL and original backups remain.\n"
    read -r -p "Continue? Type YES: " answer
    [[ "$answer" == YES ]] || {
        printf "Cancelled; no changes made.\n"
        exit 0
    }

    rm -- "$MARKER"
    if [[ -d "$BACKUP_ROOT/staged" && ! -L "$BACKUP_ROOT/staged" ]]; then
        for staged_file in "$BACKUP_ROOT/staged/.bashrc" "$BACKUP_ROOT/staged/.bashrc.base"; do
            if [[ -f "$staged_file" && ! -L "$staged_file" ]]; then
                rm -f -- "$staged_file" || fail "Could not remove temporary staging file: $staged_file"
            fi
        done
        rmdir -- "$BACKUP_ROOT/staged" 2>/dev/null ||
            printf 'WARNING: staging directory retained because it contains unexpected files.\n' >&2
    fi
    printf "Marker cleared. Backup and journal retained at: %s\n" "$BACKUP_ROOT"
    exit 0
fi

if [[ "$MODE" == apply ]]; then
    cyber_state_private_dir "$BACKUP_ROOT" || fail 'Selected backup directory is not private and user-owned.'
fi

case "$PHASE" in
    preparing|packages)
        fail "Installation stopped during '$PHASE'; file deployment had not begun. File restoration is not required. Package changes, if any, are not reversed by this tool."
        ;;
    deploying|completed) ;;
    *) fail 'Unknown installation phase.' ;;
esac

validate_relative_path() {
    local relative="$1"
    local component
    local -a components=()

    [[ -n "$relative" && "$relative" != /* ]] ||
        fail "Invalid journal path: $relative"

    [[ "$relative" != */ && "$relative" != *//* &&
       "$relative" != *'|'* && "$relative" != *$'\t'* &&
       "$relative" != *$'\n'* && "$relative" != *$'\r'* ]] ||
        fail "Unsafe journal path: $relative"

    IFS='/' read -r -a components <<< "$relative"

    for component in "${components[@]}"; do
        [[ -n "$component" && "$component" != "." &&
           "$component" != ".." ]] ||
            fail "Unsafe journal path: $relative"
    done
}

check_target() {
    local target="$1"
    local parent

    [[ ! -L "$target" ]] ||
        fail "Refusing symlink destination: $target"

    if [[ -e "$target" && ! -f "$target" ]]; then
        fail "Destination is not a regular file: $target"
    fi

    parent="$(dirname -- "$target")"

    while [[ "$parent" != "/" && "$parent" != "." ]]; do
        [[ ! -L "$parent" ]] ||
            fail "Refusing symlinked parent directory: $parent"

        if [[ -e "$parent" && ! -d "$parent" ]]; then
            fail "Parent path is not a directory: $parent"
        fi

        parent="$(dirname -- "$parent")"
    done
}

check_backup_file() {
    local backup="$1"
    local relative
    local privileged="$2"
    local base="$3"
    local parent_relative
    local parent
    local component
    local -a components=()

    [[ "$backup" == "$base/"* ]] ||
        fail "Backup path is outside its expected directory: $backup"

    relative="${backup#"$base"/}"
    validate_relative_path "$relative"

    if [[ "$privileged" == yes ]]; then
        sudo test -d "$base" && sudo test ! -L "$base" ||
            fail "Invalid system backup directory: $base"
    else
        [[ -d "$base" && ! -L "$base" ]] ||
            fail "Invalid user backup directory: $base"
    fi

    if [[ "$relative" == */* ]]; then
        parent_relative="${relative%/*}"
        IFS='/' read -r -a components <<< "$parent_relative"
    fi

    parent="$base"

    for component in "${components[@]}"; do
        parent="$parent/$component"

        if [[ "$privileged" == yes ]]; then
            sudo test -d "$parent" && sudo test ! -L "$parent" ||
                fail "Invalid system backup directory: $parent"
        else
            [[ -d "$parent" && ! -L "$parent" ]] ||
                fail "Invalid user backup directory: $parent"
        fi
    done

    if [[ "$privileged" == yes ]]; then
        sudo test -f "$backup" && sudo test ! -L "$backup" ||
            fail "Missing or invalid system backup: $backup"
    else
        [[ -f "$backup" && ! -L "$backup" ]] ||
            fail "Missing or invalid user backup: $backup"
    fi
}

KINDS=()
RELATIVES=()
EXISTED=()

declare -A JOURNAL_SEEN=()

HOME_COUNT=0
SYSTEM_COUNT=0

while IFS= read -r journal_line || [[ -n "$journal_line" ]]; do
    [[ "$journal_line" =~ ^(U|S)\|([^|]+)\|(0|1)$ ]] ||
        fail 'Malformed journal entry.'

    IFS='|' read -r kind relative existed <<< "$journal_line"

    [[ "$kind" == U || "$kind" == S ]] ||
        fail "Unknown journal entry type: $kind"

    [[ "$existed" == 0 || "$existed" == 1 ]] ||
        fail "Invalid existence flag in journal: $existed"

    validate_relative_path "$relative"

    key="$kind|$relative"

    [[ -z "${JOURNAL_SEEN[$key]+x}" ]] ||
        fail "Duplicate journal entry: $key"

    JOURNAL_SEEN["$key"]=1

    if [[ "$kind" == U ]]; then
        target="$HOME/$relative"
        backup="$BACKUP_ROOT/home/$relative"
        ((HOME_COUNT += 1))

        if [[ "$existed" == 1 ]]; then
            check_backup_file "$backup" no "$BACKUP_ROOT/home"
        fi
    else
        target="/usr/$relative"
        backup="$BACKUP_ROOT/system/$relative"
        ((SYSTEM_COUNT += 1))
    fi

    check_target "$target"

    KINDS+=("$kind")
    RELATIVES+=("$relative")
    EXISTED+=("$existed")
done < "$JOURNAL"

((${#KINDS[@]} > 0)) ||
    fail 'Journal contains no restoration entries.'

printf '\nCYBERPUNK DESKTOP RESTORE\n'
printf 'Backup: %s\n' "$BACKUP_ROOT"
printf 'Recorded phase: %s\n' "$PHASE"
printf 'User files: %s\n' "$HOME_COUNT"
printf 'System files: %s\n' "$SYSTEM_COUNT"
printf 'Existing files will be restored; files originally absent will be removed.\n'
if [[ -f "$INSTALL_STATE" && ! -L "$INSTALL_STATE" &&
      -f "$DEPLOY_PROGRESS" && ! -L "$DEPLOY_PROGRESS" &&
      -f "$RESTORE_PROGRESS" && ! -L "$RESTORE_PROGRESS" ]]; then
    printf 'Checksum/progress state: present; apply will validate exact coverage, backup hashes, progress records, and conflicts.\n'
elif [[ -e "$INSTALL_STATE" || -e "$DEPLOY_PROGRESS" || -e "$RESTORE_PROGRESS" ]]; then
    printf 'WARNING: recovery state is incomplete; protected apply will refuse.\n'
else
    printf 'WARNING: legacy backup; protected apply will refuse without state/progress manifests.\n'
fi
printf 'Restoration runs in reverse journal order.\n'
printf 'Installed packages, services, disks, and partitions will not be changed.\n'
printf '\nRecorded destinations:\n'
for i in "${!KINDS[@]}"; do
    kind="${KINDS[$i]}"; relative="${RELATIVES[$i]}"; existed="${EXISTED[$i]}"
    if [[ "$kind" == U ]]; then target="$HOME/$relative"; else target="/usr/$relative"; fi
    if [[ "$existed" == 1 ]]; then action='restore original backup'; else action='remove if verified installed'; fi
    printf '  %s — %s\n' "$target" "$action"
done

if [[ "$MODE" == plan ]]; then
    printf '\nPLAN ONLY: no files or settings have been changed.\n'
    printf 'To perform this restoration after reviewing the plan, run:\n'
    printf '  %q --apply %q\n' "$0" "$BACKUP_ROOT"
    exit 0
fi

printf '\nWARNING: this will overwrite or remove the recorded destination files.\n'
read -r -p 'Continue? Type YES: ' answer

[[ "$answer" == YES ]] || {
    printf 'Cancelled; no changes made.\n'
    exit 0
}

if ((SYSTEM_COUNT > 0)); then
    sudo -v || fail 'Could not obtain sudo authorization.'
fi

# Refuse legacy or incomplete progress records. This checks exact journal/state
# coverage, original backup hashes, progress manifests, safe paths, and every
# destination before any file is changed.
cyber_state_preflight "$INSTALL_STATE" "$JOURNAL" "$BACKUP_ROOT" "$DEPLOY_PROGRESS" "$RESTORE_PROGRESS" ||
    fail 'Protected recovery preflight failed; no files were restored.'

# Validate every destination and every required backup before changing files.
for i in "${!KINDS[@]}"; do
    kind="${KINDS[$i]}"
    relative="${RELATIVES[$i]}"
    existed="${EXISTED[$i]}"

    if [[ "$kind" == S ]]; then
        target="/usr/$relative"
        backup="$BACKUP_ROOT/system/$relative"

        check_target "$target"

        if [[ "$existed" == 1 ]]; then
            check_backup_file "$backup" yes "$BACKUP_ROOT/system"
        fi
    else
        target="$HOME/$relative"
        backup="$BACKUP_ROOT/home/$relative"

        check_target "$target"

        if [[ "$existed" == 1 ]]; then
            check_backup_file "$backup" no "$BACKUP_ROOT/home"
        fi
    fi
done

atomic_restore_user() {
    local relative="$1" backup="$2" target="$3" expected="$4" installed="$5" temporary parent actual current
    [[ -f "$backup" && ! -L "$backup" ]] || return 1
    [[ "$(cyber_state_target_path_safe U "$relative")" == "$target" ]] || return 1
    current="$(cyber_state_hash_target U "$relative")" || return 1
    [[ "${current,,}" == "${installed,,}" ]] || return 1
    parent="$(dirname -- "$target")"
    mkdir -p -- "$parent" || return 1
    temporary="$(mktemp "$parent/.cyberarch-restore.XXXXXX")" || return 1
    if ! cp -a -- "$backup" "$temporary" || [[ ! -f "$temporary" || -L "$temporary" ]]; then
        rm -f -- "$temporary"
        return 1
    fi
    actual="$(sha256sum -- "$temporary" | awk '{print $1}')" || { rm -f -- "$temporary"; return 1; }
    current="$(cyber_state_hash_target U "$relative")" || { rm -f -- "$temporary"; return 1; }
    if [[ "${actual,,}" != "${expected,,}" ]] ||
       [[ "${current,,}" != "${installed,,}" ]] ||
       [[ "$(cyber_state_target_path_safe U "$relative")" != "$target" ]] ||
       ! mv -f -- "$temporary" "$target"; then
        rm -f -- "$temporary"
        return 1
    fi
    actual="$(sha256sum -- "$target" | awk '{print $1}')" || return 1
    [[ "${actual,,}" == "${expected,,}" ]]
}

atomic_restore_system() {
    local relative="$1" backup="$2" target="$3" expected="$4" installed="$5" temporary parent actual current
    sudo /usr/bin/test -f "$backup" && sudo /usr/bin/test ! -L "$backup" || return 1
    [[ "$(cyber_state_target_path_safe S "$relative")" == "$target" ]] || return 1
    current="$(cyber_state_hash_target S "$relative")" || return 1
    [[ "${current,,}" == "${installed,,}" ]] || return 1
    parent="$(dirname -- "$target")"
    sudo mkdir -p -- "$parent" || return 1
    temporary="$(sudo mktemp "$parent/.cyberarch-restore.XXXXXX")" || return 1
    if ! sudo cp -a -- "$backup" "$temporary" ||
       ! sudo /usr/bin/test -f "$temporary" || sudo /usr/bin/test -L "$temporary"; then
        sudo rm -f -- "$temporary"
        return 1
    fi
    actual="$(sudo sha256sum -- "$temporary" | awk '{print $1}')" || { sudo rm -f -- "$temporary"; return 1; }
    current="$(cyber_state_hash_target S "$relative")" || { sudo rm -f -- "$temporary"; return 1; }
    if [[ "${actual,,}" != "${expected,,}" ]] ||
       [[ "${current,,}" != "${installed,,}" ]] ||
       [[ "$(cyber_state_target_path_safe S "$relative")" != "$target" ]] ||
       ! sudo mv -f -- "$temporary" "$target"; then
        sudo rm -f -- "$temporary"
        return 1
    fi
    actual="$(sudo sha256sum -- "$target" | awk '{print $1}')" || return 1
    [[ "${actual,,}" == "${expected,,}" ]]
}

printf '\nRestoring files...\n'

for ((i=${#KINDS[@]}-1; i>=0; i--)); do
    kind="${KINDS[$i]}"
    relative="${RELATIVES[$i]}"
    existed="${EXISTED[$i]}"
    pair="$(cyber_state_lookup "$INSTALL_STATE" "$kind" "$relative")" || fail "Missing checksum state for $kind|$relative"
    IFS='|' read -r installed original <<< "$pair"
    current="$(cyber_state_hash_target "$kind" "$relative")" || fail "Destination became unsafe: $kind|$relative"

    if [[ "$kind" == U ]]; then
        target="$HOME/$relative"
        backup="$BACKUP_ROOT/home/$relative"
    else
        target="/usr/$relative"
        backup="$BACKUP_ROOT/system/$relative"
    fi

    if [[ "${current^^}" != "${original^^}" ]]; then
        if grep -Fqx -- "$kind|$relative|$original" "$RESTORE_PROGRESS"; then
            fail "Destination changed after it was previously restored: $target"
        fi
        if [[ "${current,,}" != "${installed,,}" ]] ||
           ! grep -Fqx -- "$kind|$relative|$installed" "$DEPLOY_PROGRESS"; then
            fail "Destination changed after preflight or lacks verified deployment progress: $target"
        fi
        if [[ "$existed" == 1 ]]; then
            if [[ "$kind" == U ]]; then
                atomic_restore_user "$relative" "$backup" "$target" "$original" "$installed" || fail "Could not safely restore: $target"
            else
                atomic_restore_system "$relative" "$backup" "$target" "$original" "$installed" || fail "Could not safely restore: $target"
            fi
        else
            current="$(cyber_state_hash_target "$kind" "$relative")" || fail "Destination became unsafe before removal: $target"
            [[ "${current,,}" == "${installed,,}" ]] || fail "Destination changed before removal: $target"
            if [[ "$kind" == U ]]; then rm -f -- "$target" || fail "Could not remove originally absent file: $target"
            else sudo rm -f -- "$target" || fail "Could not remove originally absent system file: $target"
            fi
        fi
    fi

    current="$(cyber_state_hash_target "$kind" "$relative")" || fail "Could not verify restored destination: $target"
    [[ "${current^^}" == "${original^^}" ]] || fail "Restored checksum mismatch: $target"
    if ! grep -Fqx -- "$kind|$relative|$original" "$RESTORE_PROGRESS"; then
        cyber_state_append_progress "$RESTORE_PROGRESS" "$kind" "$relative" "$original" ||
            fail "Could not record restoration progress: $target"
    fi
done

if [[ -f "$MARKER" && ! -L "$MARKER" ]]; then
    rm -f -- "$MARKER"
fi

printf '\nFile restoration completed and verified.\n'
printf 'Backup retained at: %s\n' "$BACKUP_ROOT"
printf 'Package changes, if any, were not reversed.\n'
