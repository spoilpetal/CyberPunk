#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PAYLOAD="$PROJECT_DIR/payload"
REQUIRED_FILE="$PROJECT_DIR/packages/required.txt"
OFFICIAL_FILE="$PROJECT_DIR/packages/official.txt"
BUNDLED_FILE="$PROJECT_DIR/packages/bundled.txt"
DEPENDENCY_DIR="$PROJECT_DIR/dist/dependencies"
CHECKSUM_FILE="$DEPENDENCY_DIR/SHA256SUMS"
STATE_DIR="$HOME/.local/state/cyberpunk-desktop-installer"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_ROOT="$STATE_DIR/backups/$TIMESTAMP"
JOURNAL="$BACKUP_ROOT/FILE-JOURNAL"
MARKER="$BACKUP_ROOT/INSTALL-IN-PROGRESS"
INSTALL_STATE="$BACKUP_ROOT/INSTALL-STATE"
DEPLOY_PROGRESS="$BACKUP_ROOT/DEPLOY-PROGRESS"
RESTORE_PROGRESS="$BACKUP_ROOT/RESTORE-PROGRESS"
BASHRC_PATH="$HOME/.bashrc"
BASHRC_BEGIN="# >>> Cyberpunk Desktop Installer managed block >>>"
BASHRC_END="# <<< Cyberpunk Desktop Installer managed block <<<"
source "$PROJECT_DIR/scripts/recovery-state.sh"
source "$PROJECT_DIR/scripts/bashrc-integration.sh"
source "$PROJECT_DIR/scripts/sddm-integration.sh"

MODE=plan
DEPLOY_STARTED=0
ROLLBACK_RUNNING=0

usage() {
    printf 'Usage: %s [--plan|--apply|--help]\n' "${0##*/}"
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

cleanup_bashrc_stage() {
    local staged="$BACKUP_ROOT/staged" file
    [[ -d "$staged" && ! -L "$staged" ]] || return 0
    for file in "$staged/.bashrc" "$staged/.bashrc.base"; do
        if [[ -f "$file" && ! -L "$file" ]]; then
            rm -f -- "$file" || return 1
        fi
    done
    rmdir -- "$staged" 2>/dev/null || return 1
}

on_exit() {
    local status=$?
    trap - EXIT ERR INT TERM

    if ((status != 0 && DEPLOY_STARTED == 1 && ROLLBACK_RUNNING == 0)); then
        printf '\nInstallation failed. Attempting file-level rollback...\n' >&2
        rollback_files || {
            printf 'ROLLBACK INCOMPLETE. Preserve this recovery directory:\n%s\n' "$BACKUP_ROOT" >&2
            exit 1
        }
        printf 'File-level rollback completed. Package changes, if any, were not reversed.\n' >&2
        cleanup_bashrc_stage || printf 'WARNING: temporary Bash staging files could not be fully cleaned.\n' >&2
        if [[ -f "$MARKER" && ! -L "$MARKER" ]]; then
            rm -f -- "$MARKER" || {
                printf 'WARNING: rollback succeeded, but the recovery marker could not be cleared.\n' >&2
                exit 1
            }
        fi
    elif ((status != 0)); then
        cleanup_bashrc_stage || printf 'WARNING: temporary Bash staging files could not be fully cleaned.\n' >&2
    fi

    exit "$status"
}

on_error() {
    local status=$? line="${1:-unknown}"
    printf 'ERROR: command failed at line %s (exit %s).\n' "$line" "$status" >&2
    return "$status"
}

rollback_validate_relative_path() {
    local relative="$1" component
    local -a components=()

    [[ -n "$relative" && "$relative" != /* &&
       "$relative" != */ && "$relative" != *//* &&
       "$relative" != *'|'* && "$relative" != *$'\t'* &&
       "$relative" != *$'\n'* && "$relative" != *$'\r'* ]] || {
        printf 'Unsafe rollback journal path: %s\n' "$relative" >&2
        return 1
    }

    IFS='/' read -r -a components <<< "$relative"
    for component in "${components[@]}"; do
        [[ -n "$component" && "$component" != "." &&
           "$component" != ".." ]] || {
            printf 'Unsafe rollback journal path component: %s\n' "$relative" >&2
            return 1
        }
    done
}

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

rollback_files() {
    local line kind relative existed target backup pair installed original current
    local index failed=0
    local -a kinds=() relatives=() existed_flags=()

    ROLLBACK_RUNNING=1
    if [[ ! -f "$JOURNAL" || -L "$JOURNAL" || ! -d "$BACKUP_ROOT" || -L "$BACKUP_ROOT" ]]; then
        printf 'Rollback refused: recovery journal or backup directory is missing or unsafe.\n' >&2
        ROLLBACK_RUNNING=0
        return 1
    fi

    while IFS='|' read -r kind relative existed || [[ -n "${kind:-}" ]]; do
        [[ "$kind" =~ ^(U|S)$ && "$existed" =~ ^[01]$ ]] || {
            printf 'Rollback refused: malformed journal entry.\n' >&2
            ROLLBACK_RUNNING=0
            return 1
        }
        rollback_validate_relative_path "$relative" || { ROLLBACK_RUNNING=0; return 1; }
        kinds+=("$kind"); relatives+=("$relative"); existed_flags+=("$existed")
    done < "$JOURNAL"

    ((${#kinds[@]} > 0)) || {
        printf 'Rollback refused: journal contains no entries.\n' >&2
        ROLLBACK_RUNNING=0
        return 1
    }

    # Obtain privilege before any user or system file is restored.
    sudo -v || {
        printf 'Rollback refused: sudo authorization is required before any files can be restored.\n' >&2
        ROLLBACK_RUNNING=0
        return 1
    }

    # This validates exact journal/state coverage, every backup checksum, all
    # progress records, and every current destination before the first mutation.
    cyber_state_preflight "$INSTALL_STATE" "$JOURNAL" "$BACKUP_ROOT" "$DEPLOY_PROGRESS" "$RESTORE_PROGRESS" || {
        ROLLBACK_RUNNING=0
        return 1
    }

    for ((index=${#kinds[@]}-1; index>=0; index--)); do
        kind="${kinds[$index]}"; relative="${relatives[$index]}"; existed="${existed_flags[$index]}"
        pair="$(cyber_state_lookup "$INSTALL_STATE" "$kind" "$relative")" || { failed=1; break; }
        IFS='|' read -r installed original <<< "$pair"
        current="$(cyber_state_hash_target "$kind" "$relative")" || { failed=1; break; }
        target="$HOME/$relative"; backup="$BACKUP_ROOT/home/$relative"
        [[ "$kind" == S ]] && { target="/usr/$relative"; backup="$BACKUP_ROOT/system/$relative"; }

        if [[ "${current^^}" != "${original^^}" ]]; then
            if grep -Fqx -- "$kind|$relative|$original" "$RESTORE_PROGRESS"; then
                printf 'Rollback conflict: previously restored destination changed: %s\n' "$target" >&2
                failed=1; break
            fi
            if [[ "${current,,}" != "${installed,,}" ]] ||
               ! grep -Fqx -- "$kind|$relative|$installed" "$DEPLOY_PROGRESS"; then
                printf 'Rollback conflict: destination changed after preflight: %s\n' "$target" >&2
                failed=1; break
            fi
            if [[ "$existed" == 1 ]]; then
                if [[ "$kind" == U ]]; then
                    atomic_restore_user "$relative" "$backup" "$target" "$original" "$installed" || { failed=1; break; }
                else
                    atomic_restore_system "$relative" "$backup" "$target" "$original" "$installed" || { failed=1; break; }
                fi
            else
                current="$(cyber_state_hash_target "$kind" "$relative")" || { failed=1; break; }
                [[ "${current,,}" == "${installed,,}" ]] || { failed=1; break; }
                if [[ "$kind" == U ]]; then rm -f -- "$target" || { failed=1; break; }
                else sudo rm -f -- "$target" || { failed=1; break; }
                fi
            fi
        fi

        current="$(cyber_state_hash_target "$kind" "$relative")" || { failed=1; break; }
        [[ "${current^^}" == "${original^^}" ]] || { failed=1; break; }
        if ! grep -Fqx -- "$kind|$relative|$original" "$RESTORE_PROGRESS"; then
            cyber_state_append_progress "$RESTORE_PROGRESS" "$kind" "$relative" "$original" || { failed=1; break; }
        fi
    done

    ROLLBACK_RUNNING=0
    return "$failed"
}


write_marker() {
    local phase="$1"
    local temporary
    temporary="$(mktemp "$BACKUP_ROOT/.INSTALL-IN-PROGRESS.XXXXXX")" ||
        fail 'Could not create temporary installation marker.'
    if ! printf 'phase=%s\nbackup=%s\n' "$phase" "$BACKUP_ROOT" > "$temporary" ||
       ! mv -f -- "$temporary" "$MARKER"; then
        rm -f -- "$temporary"
        fail 'Could not update installation marker.'
    fi
}

trap 'on_exit $?' EXIT
trap 'on_error "$LINENO"' ERR
trap 'exit 130' INT
trap 'exit 143' TERM

case "${1:-}" in
    --plan) MODE=plan ;;
    --apply) MODE=apply ;;
    --help|-h) usage; exit 0 ;;
    "") MODE=plan ;;
    *) usage >&2; fail "Unknown argument: $1" ;;
esac
[[ $# -le 1 ]] || fail 'Only one mode argument is supported.'

[[ $EUID -ne 0 ]] || fail 'Run as the normal desktop user, not root.'
[[ -f /etc/arch-release ]] || fail 'Arch Linux is required.'
[[ "$(uname -m)" == x86_64 ]] || fail 'This bundle currently supports x86_64 only (Wallust archive is x86_64).'
[[ "$HOME" == /* && "$HOME" != / ]] || fail 'A valid non-root home directory is required.'
[[ -d "$PAYLOAD/home" && -d "$PAYLOAD/usr" ]] || fail 'Payload is incomplete.'
[[ -s "$REQUIRED_FILE" && -s "$OFFICIAL_FILE" && -s "$BUNDLED_FILE" ]] || fail 'Package manifests are missing.'
[[ -f "$CHECKSUM_FILE" && ! -L "$CHECKSUM_FILE" && -s "$CHECKSUM_FILE" ]] || fail 'Bundled package checksum file is missing or unsafe.'

for tool in pacman pacman-conf sudo sha256sum find awk sort stat sync grep mktemp chmod; do
    command -v "$tool" >/dev/null 2>&1 || fail "Required command not found: $tool"
done

read_manifest() {
    local file="$1" line
    local -n result="$2"
    result=()

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        [[ "$line" =~ ^[a-zA-Z0-9@._+-]+$ ]] ||
            fail "Invalid package entry in $file: $line"
        result+=("$line")
    done < "$file"

    ((${#result[@]} > 0)) || fail "No packages found in $file"
}

read_manifest "$REQUIRED_FILE" REQUIRED_PACKAGES
read_manifest "$OFFICIAL_FILE" OFFICIAL_PACKAGES
read_manifest "$BUNDLED_FILE" BUNDLED_PACKAGES

declare -A seen=()
for package in "${OFFICIAL_PACKAGES[@]}" "${BUNDLED_PACKAGES[@]}"; do
    [[ -z "${seen[$package]+x}" ]] || fail "Duplicate package in manifests: $package"
    seen["$package"]=1
done
declare -A required_seen=()
for package in "${REQUIRED_PACKAGES[@]}"; do
    [[ -z "${required_seen[$package]+x}" ]] || fail "Duplicate required package: $package"
    required_seen["$package"]=1
done
for package in "${OFFICIAL_PACKAGES[@]}" "${BUNDLED_PACKAGES[@]}"; do
    [[ -n "${required_seen[$package]+x}" ]] ||
        fail "Package is listed for installation but missing from required.txt: $package"
    unset 'required_seen[$package]'
done
((${#required_seen[@]} == 0)) ||
    fail 'required.txt contains packages absent from official.txt and bundled.txt.'

EXPECTED_ARCHIVES=(
    neofetch-7.1.0-2-any.pkg.tar.zst
    ttf-oxanium-2.000-2-any.pkg.tar.zst
    ttf-rajdhani-2.000-0-any.pkg.tar.zst
    wallust-3.5.2-2-x86_64.pkg.tar.zst
)

shopt -s nullglob
ARCHIVES=("$DEPENDENCY_DIR"/*.pkg.tar.zst)
shopt -u nullglob

((${#ARCHIVES[@]} == ${#EXPECTED_ARCHIVES[@]})) ||
    fail 'Unexpected number of bundled package archives.'

for expected in "${EXPECTED_ARCHIVES[@]}"; do
    [[ -f "$DEPENDENCY_DIR/$expected" && ! -L "$DEPENDENCY_DIR/$expected" ]] ||
        fail "Missing or invalid bundled archive: $expected"
done

ACTUAL_NAMES=()
for archive in "${ARCHIVES[@]}"; do
    ACTUAL_NAMES+=("${archive##*/}")
done

mapfile -t ACTUAL_SORTED < <(printf '%s\n' "${ACTUAL_NAMES[@]}" | sort)
mapfile -t EXPECTED_SORTED < <(printf '%s\n' "${EXPECTED_ARCHIVES[@]}" | sort)
[[ "${ACTUAL_SORTED[*]}" == "${EXPECTED_SORTED[*]}" ]] ||
    fail 'Bundled archive filenames do not match the approved set.'

awk '
    NF != 2 || length($1) != 64 || $1 ~ /[^0-9a-fA-F]/ || $2 !~ /^\.\/[A-Za-z0-9._+-]+\.pkg\.tar\.zst$/ {
        print "Invalid checksum manifest line: " $0 > "/dev/stderr"
        bad=1
        next
    }
    {
        name=$2
        sub(/^\.\//, "", name)
        if (seen[name]++) {
            print "Duplicate checksum entry: " name > "/dev/stderr"
            bad=1
        }
        entries[name]=1
    }
    END {
        expected["neofetch-7.1.0-2-any.pkg.tar.zst"]=1
        expected["ttf-oxanium-2.000-2-any.pkg.tar.zst"]=1
        expected["ttf-rajdhani-2.000-0-any.pkg.tar.zst"]=1
        expected["wallust-3.5.2-2-x86_64.pkg.tar.zst"]=1
        for (name in expected) if (!entries[name]) {
            print "Missing checksum entry: " name > "/dev/stderr"
            bad=1
        }
        for (name in entries) if (!expected[name]) {
            print "Unexpected checksum entry: " name > "/dev/stderr"
            bad=1
        }
        exit bad
    }
' "$CHECKSUM_FILE" || fail 'Checksum manifest structure is invalid.'

(
    cd "$DEPENDENCY_DIR"
    sha256sum --check --strict SHA256SUMS
) || fail 'Bundled package checksum verification failed.'

BUNDLED_FILES=()
declare -A archive_names=()
for archive in "${ARCHIVES[@]}"; do
    package_name="$(pacman -Qp -- "$archive" | awk 'NR==1 {print $1}')"
    [[ -n "$package_name" ]] || fail "Cannot read package metadata: $archive"
    [[ -z "${archive_names[$package_name]+x}" ]] || fail "Duplicate bundled archive: $package_name"
    archive_names["$package_name"]=1
    [[ -n "${seen[$package_name]+x}" ]] || fail "Archive not listed in manifests: $package_name"
    BUNDLED_FILES+=("$archive")
done

for package in "${BUNDLED_PACKAGES[@]}"; do
    [[ -n "${archive_names[$package]+x}" ]] ||
        fail "Missing bundled archive for package: $package"
done
LOCAL_FILE_SIGLEVEL="$(pacman-conf LocalFileSigLevel 2>/dev/null || true)"
[[ -n "$LOCAL_FILE_SIGLEVEL" ]] || fail 'Could not read pacman LocalFileSigLevel from pacman.conf.'
if [[ "$LOCAL_FILE_SIGLEVEL" == *Required* && "$MODE" == apply ]]; then
    fail 'Bundled package archives are unsigned, but LocalFileSigLevel requires signatures. No system changes were made. Use trusted signed archives or a trusted signing setup; this installer will not weaken pacman signature policy.'
fi

validate_relative_path() {
    local relative="$1" component
    [[ -n "$relative" && "$relative" != /* ]] || fail "Invalid relative path: $relative"
    [[ "$relative" != *'|'* && "$relative" != *$'\t'* && "$relative" != *$'\n'* && "$relative" != *$'\r'* ]] ||
        fail "Unsupported character in payload path: $relative"

    IFS='/' read -r -a components <<< "$relative"
    for component in "${components[@]}"; do
        [[ "$component" != "." && "$component" != ".." && -n "$component" ]] ||
            fail "Unsafe payload path: $relative"
    done
}

check_destination() {
    local target="$1" parent

    [[ ! -L "$target" ]] || fail "Refusing symlink destination: $target"
    if [[ -e "$target" && ! -f "$target" ]]; then
        fail "Destination exists but is not a regular file: $target"
    fi

    parent="$(dirname -- "$target")"
    while [[ "$parent" != "/" && "$parent" != "." ]]; do
        [[ ! -L "$parent" ]] || fail "Refusing symlinked parent directory: $parent"
        if [[ -e "$parent" && ! -d "$parent" ]]; then
            fail "Parent path is not a directory: $parent"
        fi
        parent="$(dirname -- "$parent")"
    done
}

# Reject anything in the payload that is not a regular file or directory.
# Do not silently ignore symlinks, devices, FIFOs, sockets, or other special files.
while IFS= read -r -d '' payload_entry; do
    fail "Unsupported payload entry type: $payload_entry"
done < <(find "$PAYLOAD" -mindepth 1 ! -type d ! -type f -print0)

HOME_FILES=()
HOME_RELATIVES=()
SYSTEM_FILES=()
SYSTEM_RELATIVES=()

while IFS= read -r -d '' source_file; do
    relative="${source_file#"$PAYLOAD/home/"}"
    validate_relative_path "$relative"
    target="$HOME/$relative"
    check_destination "$target"
    HOME_FILES+=("$source_file")
    HOME_RELATIVES+=("$relative")
done < <(find "$PAYLOAD/home" -type f -print0)

while IFS= read -r -d '' source_file; do
    relative="${source_file#"$PAYLOAD/usr/"}"
    validate_relative_path "$relative"
    target="/usr/$relative"
    check_destination "$target"
    SYSTEM_FILES+=("$source_file")
    SYSTEM_RELATIVES+=("$relative")
done < <(find "$PAYLOAD/usr" -type f -print0)

cyber_bashrc_validate "$BASHRC_PATH" "$BASHRC_BEGIN" "$BASHRC_END" || fail 'Unsafe .bashrc managed-block state.'

((${#HOME_FILES[@]} > 0 && ${#SYSTEM_FILES[@]} > 0)) ||
    fail 'Expected both home and system payload files.'

if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    SESSION='Wayland'
elif [[ -n "${DISPLAY:-}" ]]; then
    SESSION='X11'
else
    SESSION='TTY'
fi

printf '\nCYBERPUNK DESKTOP INSTALLER\n'
printf 'System: Arch Linux\nSession: %s\nUser: %s\n' "$SESSION" "${USER:-unknown}"
printf 'Official repository packages: %s\n' "${#OFFICIAL_PACKAGES[@]}"
printf 'Official package set: %s\n' "${OFFICIAL_PACKAGES[*]}"
printf 'Bundled package set: %s\n' "${BUNDLED_PACKAGES[*]}"
printf 'pacman LocalFileSigLevel: %s\n' "$LOCAL_FILE_SIGLEVEL"
if [[ "$LOCAL_FILE_SIGLEVEL" == *Required* ]]; then printf 'WARNING: unsigned bundled archives will be refused; apply is blocked until trusted signed archives are provided.\n'; fi
printf 'Bundled packages: %s\n' "${#BUNDLED_PACKAGES[@]}"
printf 'Home payload files: %s\n' "${#HOME_FILES[@]}"
printf 'System payload files: %s\n' "${#SYSTEM_FILES[@]}"
printf 'Additional managed shell file: %s\n' "$BASHRC_PATH"
if [[ "$MODE" == plan ]]; then
    printf 'Backup destination: %s/backups/<timestamped directory> (created only on --apply)\n' "$STATE_DIR"
else
    printf 'Backup destination: %s\n' "$BACKUP_ROOT"
fi
printf 'SDDM: --apply will ask whether to enable sddm.service at boot; the default is No.\n'
printf 'Bash integration: a managed Cyberpunk prompt block will be added to .bashrc; all other lines are preserved.\n'
printf 'Existing destination files will be backed up before replacement.\n'
printf 'No disk formatting, partition changes, or personal-file deletion will occur.\n'
printf '\nUser configuration destinations:\n'
for relative in "${HOME_RELATIVES[@]}"; do printf '  %s\n' "$HOME/$relative"; done
printf '  %s (managed prompt block)\n' "$BASHRC_PATH"
printf 'System theme destinations:\n'
for relative in "${SYSTEM_RELATIVES[@]}"; do printf '  /usr/%s\n' "$relative"; done

if [[ "$MODE" == plan ]]; then
    printf '\nPLAN ONLY: no packages, files, services, or settings will be changed.\n'
    printf 'To perform the installation after reviewing this plan, run:\n'
    printf '  %q --apply\n' "$0"
    exit 0
fi

printf '\nWARNING: --apply will run a full pacman -Syu system upgrade, install bundled packages, and deploy desktop files.\n'
read -r -p 'Continue? Type YES: ' answer
[[ "$answer" == YES ]] || { printf 'Cancelled; no changes made.\n'; exit 0; }

cyber_sddm_prompt_boot_enable || fail 'SDDM choice was not confirmed; no installation changes made.'

command -v flock >/dev/null 2>&1 || fail 'Required command not found: flock'
[[ -d "$HOME" && ! -L "$HOME" ]] || fail 'Home directory must be a real directory, not a symlink.'
for parent in "$HOME/.local" "$HOME/.local/state"; do
    [[ ! -L "$parent" ]] || fail "Refusing symlinked state parent: $parent"
    [[ ! -e "$parent" || -d "$parent" ]] || fail "State parent is not a directory: $parent"
done
mkdir -p -- "$STATE_DIR"
[[ -d "$STATE_DIR" && ! -L "$STATE_DIR" ]] || fail "Invalid installer state directory."
[[ "$(stat -c '%u' -- "$STATE_DIR")" == "$EUID" ]] || fail "Installer state directory is not owned by the current user."
chmod 700 -- "$STATE_DIR" || fail "Could not secure installer state directory."
[[ ! -L "$STATE_DIR/operation.lock" ]] || fail "Refusing a symlinked operation lock."
[[ ! -e "$STATE_DIR/operation.lock" || -f "$STATE_DIR/operation.lock" ]] || fail "Installer operation lock is not a regular file."
exec 9>>"$STATE_DIR/operation.lock"
cyber_state_private_file "$STATE_DIR/operation.lock" || fail "Installer operation lock has unsafe ownership or permissions."
flock -n 9 || fail 'Another installer or recovery operation is already running.'

sudo -v || fail 'Could not obtain sudo authorization.'

mkdir -p -- "$STATE_DIR/backups"
[[ -d "$STATE_DIR/backups" && ! -L "$STATE_DIR/backups" ]] || fail "Invalid installer backups directory."
[[ "$(stat -c '%u' -- "$STATE_DIR/backups")" == "$EUID" ]] || fail "Installer backups directory is not owned by the current user."
chmod 700 -- "$STATE_DIR/backups" || fail "Could not secure installer backups directory."
mkdir -- "$BACKUP_ROOT" || fail 'Could not create a unique backup directory.'
mkdir -p -- "$BACKUP_ROOT/home"
sudo mkdir -p -- "$BACKUP_ROOT/system"
: > "$JOURNAL"
write_marker preparing
cyber_bashrc_stage "$BASHRC_PATH" "$BACKUP_ROOT/staged/.bashrc" "$BACKUP_ROOT/staged/.bashrc.base" "$BASHRC_BEGIN" "$BASHRC_END" ".local/share/cyberpunk-theme/shell/cyberpunk-prompt.sh" || fail 'Could not safely stage the managed .bashrc integration.'
HOME_FILES+=("$BACKUP_ROOT/staged/.bashrc")
HOME_RELATIVES+=(".bashrc")

printf '\nPreparing backups of existing destination files...\n'

for index in "${!HOME_FILES[@]}"; do
    source_file="${HOME_FILES[$index]}"
    relative="${HOME_RELATIVES[$index]}"
    target="$HOME/$relative"
    check_destination "$target"

    if [[ -e "$target" ]]; then
        mkdir -p -- "$BACKUP_ROOT/home/$(dirname -- "$relative")"
        cp -a -- "$target" "$BACKUP_ROOT/home/$relative"
        printf 'U|%s|1\n' "$relative" >> "$JOURNAL"
    else
        printf 'U|%s|0\n' "$relative" >> "$JOURNAL"
    fi
done

for index in "${!SYSTEM_FILES[@]}"; do
    source_file="${SYSTEM_FILES[$index]}"
    relative="${SYSTEM_RELATIVES[$index]}"
    target="/usr/$relative"
    check_destination "$target"

    if [[ -e "$target" ]]; then
        sudo mkdir -p -- "$BACKUP_ROOT/system/$(dirname -- "$relative")"
        sudo cp -a -- "$target" "$BACKUP_ROOT/system/$relative"
        printf 'S|%s|1\n' "$relative" >> "$JOURNAL"
    else
        printf 'S|%s|0\n' "$relative" >> "$JOURNAL"
    fi
done

# Record expected installed and original checksums before package/deployment phases.
# This also permits safe rollback after a crash: each file must match either its
# installed payload or its original backup state; partial copies become conflicts.
state_tmp="$(mktemp "$BACKUP_ROOT/.INSTALL-STATE.XXXXXX")" || fail 'Could not create INSTALL-STATE.'
for index in "${!HOME_FILES[@]}"; do
    source_file="${HOME_FILES[$index]}"
    relative="${HOME_RELATIVES[$index]}"
    installed_hash="$(sha256sum -- "$source_file" | awk '{print $1}')"
    original_hash=ABSENT
    if [[ -f "$BACKUP_ROOT/home/$relative" ]]; then
        original_hash="$(sha256sum -- "$BACKUP_ROOT/home/$relative" | awk '{print $1}')"
    fi
    printf 'U|%s|%s|%s\n' "$relative" "$installed_hash" "$original_hash" >> "$state_tmp"
done
for index in "${!SYSTEM_FILES[@]}"; do
    source_file="${SYSTEM_FILES[$index]}"
    relative="${SYSTEM_RELATIVES[$index]}"
    installed_hash="$(sha256sum -- "$source_file" | awk '{print $1}')"
    original_hash=ABSENT
    if sudo test -f "$BACKUP_ROOT/system/$relative"; then
        original_hash="$(sudo sha256sum -- "$BACKUP_ROOT/system/$relative" | awk '{print $1}')"
    fi
    printf 'S|%s|%s|%s\n' "$relative" "$installed_hash" "$original_hash" >> "$state_tmp"
done
mv -f -- "$state_tmp" "$INSTALL_STATE" || fail 'Could not finalize INSTALL-STATE.'
: > "$DEPLOY_PROGRESS"
: > "$RESTORE_PROGRESS"
chmod 600 "$DEPLOY_PROGRESS" "$RESTORE_PROGRESS"
sync -f "$INSTALL_STATE"
sync -f "$JOURNAL"
sync -f "$DEPLOY_PROGRESS"
sync -f "$RESTORE_PROGRESS"

write_marker packages

printf '\nInstalling official repository packages...\n'
sudo pacman -Syu --needed "${OFFICIAL_PACKAGES[@]}" ||
    fail "Official package installation failed. Backup retained at $BACKUP_ROOT"

printf '\nInstalling verified bundled packages...\n'
sudo pacman -U --needed "${BUNDLED_FILES[@]}" ||
    fail "Bundled package installation failed. Backup retained at $BACKUP_ROOT"

write_marker deploying
DEPLOY_STARTED=1

printf '\nDeploying user configuration...\n'
for index in "${!HOME_FILES[@]}"; do
    source_file="${HOME_FILES[$index]}"
    relative="${HOME_RELATIVES[$index]}"
    target="$HOME/$relative"
    check_destination "$target"
    parent="$(dirname -- "$target")"
    mkdir -p -- "$parent"
    [[ -f "$source_file" && ! -L "$source_file" ]] || fail "Unsafe user payload source: $source_file"
    temporary="$(mktemp "$parent/.cyberarch-deploy.XXXXXX")"
    if ! cp -a -- "$source_file" "$temporary" || [[ ! -f "$temporary" || -L "$temporary" ]]; then
        rm -f -- "$temporary"
        fail "Could not stage user file: $relative"
    fi
    expected_hash="$(sha256sum -- "$source_file" | awk '{print $1}')" || { rm -f -- "$temporary"; fail "Could not hash user payload: $relative"; }
    staged_hash="$(sha256sum -- "$temporary" | awk '{print $1}')" || { rm -f -- "$temporary"; fail "Could not hash staged user file: $relative"; }
    [[ "${staged_hash,,}" == "${expected_hash,,}" ]] || { rm -f -- "$temporary"; fail "Staged user file checksum mismatch: $relative"; }
    mv -f -- "$temporary" "$target" || { rm -f -- "$temporary"; fail "Could not deploy user file: $relative"; }
    actual_hash="$(sha256sum -- "$target" | awk '{print $1}')"
    [[ "${actual_hash,,}" == "${expected_hash,,}" ]] || fail "Deployed user file checksum mismatch: $relative"
    cyber_state_append_progress "$DEPLOY_PROGRESS" U "$relative" "$expected_hash" || fail "Could not record deployed user file: $relative"
done

printf 'Deploying system theme files...\n'
for index in "${!SYSTEM_FILES[@]}"; do
    source_file="${SYSTEM_FILES[$index]}"
    relative="${SYSTEM_RELATIVES[$index]}"
    target="/usr/$relative"
    check_destination "$target"
    parent="$(dirname -- "$target")"
    sudo mkdir -p -- "$parent"
    [[ -f "$source_file" && ! -L "$source_file" ]] || fail "Unsafe system payload source: $source_file"
    temporary="$(sudo mktemp "$parent/.cyberarch-deploy.XXXXXX")"
    if ! sudo cp -a -- "$source_file" "$temporary" ||
       ! sudo /usr/bin/test -f "$temporary" || sudo /usr/bin/test -L "$temporary"; then
        sudo rm -f -- "$temporary"
        fail "Could not stage system file: $relative"
    fi
    expected_hash="$(sha256sum -- "$source_file" | awk '{print $1}')" || { sudo rm -f -- "$temporary"; fail "Could not hash system payload: $relative"; }
    staged_hash="$(sudo sha256sum -- "$temporary" | awk '{print $1}')" || { sudo rm -f -- "$temporary"; fail "Could not hash staged system file: $relative"; }
    [[ "${staged_hash,,}" == "${expected_hash,,}" ]] || { sudo rm -f -- "$temporary"; fail "Staged system file checksum mismatch: $relative"; }
    sudo mv -f -- "$temporary" "$target" || { sudo rm -f -- "$temporary"; fail "Could not deploy system file: $relative"; }
    actual_hash="$(sudo sha256sum -- "$target" | awk '{print $1}')"
    [[ "${actual_hash,,}" == "${expected_hash,,}" ]] || fail "Deployed system file checksum mismatch: $relative"
    cyber_state_append_progress "$DEPLOY_PROGRESS" S "$relative" "$expected_hash" || fail "Could not record deployed system file: $relative"
done

LATEST_TMP="$(mktemp "$STATE_DIR/.latest-backup.XXXXXX")" ||
    fail 'Could not create temporary latest-backup record.'

if ! printf '%s\n' "$BACKUP_ROOT" > "$LATEST_TMP" ||
   ! mv -f -- "$LATEST_TMP" "$STATE_DIR/latest-backup"; then
    rm -f -- "$LATEST_TMP"
    fail 'Could not update latest-backup record.'
fi

DEPLOY_STARTED=0
cleanup_bashrc_stage || fail 'Could not clean temporary Bash staging files.'
rm -f -- "$MARKER" || fail 'Could not remove completed installation marker.'

if ((CYBER_SDDM_BOOT_ENABLE == 1)); then
    if cyber_sddm_enable_at_boot; then
        printf 'SDDM is enabled to start at boot. It was not started in the current session.\n'
    else
        printf 'WARNING: SDDM could not be enabled. The desktop files were installed; enable it later with: sudo systemctl enable sddm.service\n' >&2
    fi
else
    printf 'SDDM boot enablement was declined; its current service state was left unchanged.\n'
fi

printf '\nInstallation finished successfully.\n'
printf 'Backup location: %s\n' "$BACKUP_ROOT"
printf 'The managed Cyberpunk prompt block was added to .bashrc; existing content was preserved.\n'
printf 'File restoration instructions will be provided in docs/RESTORE.md.\n'
