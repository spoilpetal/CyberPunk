#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_HOME="$(mktemp -d)"
trap 'rm -rf -- "$TEST_HOME"' EXIT
export HOME="$TEST_HOME/home"
mkdir -p "$HOME/example" "$TEST_HOME/backups/20261118-120000/home/example"
BACKUP_ROOT="$TEST_HOME/backups/20261118-120000"
chmod 700 "$BACKUP_ROOT"
source "$ROOT/scripts/recovery-state.sh"

JOURNAL="$BACKUP_ROOT/FILE-JOURNAL"
STATE="$BACKUP_ROOT/INSTALL-STATE"
DEPLOY="$BACKUP_ROOT/DEPLOY-PROGRESS"
RESTORE="$BACKUP_ROOT/RESTORE-PROGRESS"

printf 'original content\n' > "$BACKUP_ROOT/home/example/managed.conf"
printf 'installed payload\n' > "$HOME/example/managed.conf"
installed_hash="$(sha256sum "$HOME/example/managed.conf" | awk '{print $1}')"
original_hash="$(sha256sum "$BACKUP_ROOT/home/example/managed.conf" | awk '{print $1}')"
printf 'U|example/managed.conf|1\n' > "$JOURNAL"
printf 'U|example/managed.conf|%s|%s\n' "$installed_hash" "$original_hash" > "$STATE"
printf 'U|example/managed.conf|%s\n' "$installed_hash" > "$DEPLOY"
: > "$RESTORE"
chmod 600 "$JOURNAL" "$STATE" "$DEPLOY" "$RESTORE"

cyber_state_preflight "$STATE" "$JOURNAL" "$BACKUP_ROOT" "$DEPLOY" "$RESTORE"
printf 'PASS: exact journal/state coverage, backup hash, and verified deployment accepted\n'

# Already-restored original state is a safe retry.
cp -a "$BACKUP_ROOT/home/example/managed.conf" "$HOME/example/managed.conf"
cyber_state_preflight "$STATE" "$JOURNAL" "$BACKUP_ROOT" "$DEPLOY" "$RESTORE"
printf 'PASS: original version accepted for interrupted-restore retry\n'

# A user edit must stop the whole operation.
printf 'user edits\n' > "$HOME/example/managed.conf"
if cyber_state_preflight "$STATE" "$JOURNAL" "$BACKUP_ROOT" "$DEPLOY" "$RESTORE" >/dev/null 2>&1; then
    printf 'FAIL: user modification was accepted\n' >&2; exit 1
fi
printf 'PASS: user modification rejected\n'

# A previously restored path that changes again must remain a conflict.
cp -a "$BACKUP_ROOT/home/example/managed.conf" "$HOME/example/managed.conf"
printf 'U|example/managed.conf|%s\n' "$original_hash" > "$RESTORE"
cyber_state_preflight "$STATE" "$JOURNAL" "$BACKUP_ROOT" "$DEPLOY" "$RESTORE"
printf 'user changed after restore\n' > "$HOME/example/managed.conf"
if cyber_state_preflight "$STATE" "$JOURNAL" "$BACKUP_ROOT" "$DEPLOY" "$RESTORE" >/dev/null 2>&1; then
    printf 'FAIL: post-restore user modification was accepted\n' >&2; exit 1
fi
: > "$RESTORE"
printf 'PASS: modification after recorded restore rejected\n'

# A destination matching installed content without a deployment record is ambiguous.
printf 'installed payload\n' > "$HOME/example/managed.conf"
: > "$DEPLOY"
if cyber_state_preflight "$STATE" "$JOURNAL" "$BACKUP_ROOT" "$DEPLOY" "$RESTORE" >/dev/null 2>&1; then
    printf 'FAIL: unrecorded deployment was accepted\n' >&2; exit 1
fi
printf 'PASS: installed content without deployment progress rejected\n'
printf 'U|example/managed.conf|%s\n' "$installed_hash" > "$DEPLOY"

# Partial copies are conflicts.
printf 'partial copy\n' > "$HOME/example/managed.conf"
if cyber_state_preflight "$STATE" "$JOURNAL" "$BACKUP_ROOT" "$DEPLOY" "$RESTORE" >/dev/null 2>&1; then
    printf 'FAIL: partial copy was accepted\n' >&2; exit 1
fi
printf 'PASS: partial-copy conflict rejected\n'

# Backup tampering must be caught even if destination is still installed.
printf 'installed payload\n' > "$HOME/example/managed.conf"
printf 'tampered backup\n' > "$BACKUP_ROOT/home/example/managed.conf"
if cyber_state_preflight "$STATE" "$JOURNAL" "$BACKUP_ROOT" "$DEPLOY" "$RESTORE" >/dev/null 2>&1; then
    printf 'FAIL: tampered backup was accepted\n' >&2; exit 1
fi
printf 'PASS: original backup checksum mismatch rejected\n'

# Journal/state mismatch must be rejected.
printf 'original content\n' > "$BACKUP_ROOT/home/example/managed.conf"
printf 'U|example/managed.conf|1\nU|example/extra.conf|0\n' > "$JOURNAL"
if cyber_state_preflight "$STATE" "$JOURNAL" "$BACKUP_ROOT" "$DEPLOY" "$RESTORE" >/dev/null 2>&1; then
    printf 'FAIL: incomplete state coverage was accepted\n' >&2; exit 1
fi
printf 'PASS: journal/state coverage mismatch rejected\n'
printf 'U|example/managed.conf|1\n' > "$JOURNAL"

# Duplicate entries and unsafe paths are rejected.
printf 'U|example/managed.conf|%s|%s\nU|example/managed.conf|%s|%s\n' "$installed_hash" "$original_hash" "$installed_hash" "$original_hash" > "$STATE"
if cyber_state_preflight "$STATE" "$JOURNAL" "$BACKUP_ROOT" "$DEPLOY" "$RESTORE" >/dev/null 2>&1; then
    printf 'FAIL: duplicate state entry was accepted\n' >&2; exit 1
fi
printf 'PASS: duplicate state entry rejected\n'
printf 'U|../outside|%s|%s\n' "$installed_hash" "$original_hash" > "$STATE"
if cyber_state_preflight "$STATE" "$JOURNAL" "$BACKUP_ROOT" "$DEPLOY" "$RESTORE" >/dev/null 2>&1; then
    printf 'FAIL: traversal path was accepted\n' >&2; exit 1
fi
printf 'PASS: traversal path rejected\n'

# Symlinked destination parents are rejected.
rm -rf "$HOME/example"
mkdir -p "$TEST_HOME/real-example"
ln -s "$TEST_HOME/real-example" "$HOME/example"
printf 'U|example/managed.conf|%s|%s\n' "$installed_hash" "$original_hash" > "$STATE"
printf 'installed payload\n' > "$TEST_HOME/real-example/managed.conf"
if cyber_state_preflight "$STATE" "$JOURNAL" "$BACKUP_ROOT" "$DEPLOY" "$RESTORE" >/dev/null 2>&1; then
    printf 'FAIL: symlinked destination parent was accepted\n' >&2; exit 1
fi
printf 'PASS: symlinked destination parent rejected\n'


# Originally absent destinations are removed only after a recorded deployment.
rm -f "$HOME/example"
mkdir -p "$HOME/example"
installed_new_hash="$(printf 'new payload\n' | sha256sum | cut -d' ' -f1)"
printf 'U|example/new.conf|0\n' > "$JOURNAL"
printf 'U|example/new.conf|%s|ABSENT\n' "$installed_new_hash" > "$STATE"
printf 'U|example/new.conf|%s\n' "$installed_new_hash" > "$DEPLOY"
: > "$RESTORE"
printf 'new payload\n' > "$HOME/example/new.conf"
cyber_state_preflight "$STATE" "$JOURNAL" "$BACKUP_ROOT" "$DEPLOY" "$RESTORE"
printf 'PASS: originally absent deployed file accepted for removal\n'
rm "$HOME/example/new.conf"
cyber_state_preflight "$STATE" "$JOURNAL" "$BACKUP_ROOT" "$DEPLOY" "$RESTORE"
printf 'PASS: already absent original state accepted\n'
printf 'user content\n' > "$HOME/example/new.conf"
if cyber_state_preflight "$STATE" "$JOURNAL" "$BACKUP_ROOT" "$DEPLOY" "$RESTORE" >/dev/null 2>&1; then
    printf 'FAIL: unexpected file at originally absent path was accepted\n' >&2; exit 1
fi
rm "$HOME/example/new.conf"
printf 'PASS: unexpected content at originally absent path rejected\n'

# A symlink in the backup tree is rejected even when no original backup should exist.
rm -rf "$BACKUP_ROOT/home/example"
mkdir -p "$TEST_HOME/external-backup"
ln -s "$TEST_HOME/external-backup" "$BACKUP_ROOT/home/example"
if cyber_state_preflight "$STATE" "$JOURNAL" "$BACKUP_ROOT" "$DEPLOY" "$RESTORE" >/dev/null 2>&1; then
    printf 'FAIL: symlinked backup parent for absent file was accepted\n' >&2; exit 1
fi
rm "$BACKUP_ROOT/home/example"
mkdir -p "$BACKUP_ROOT/home/example"
printf 'PASS: symlinked backup parent rejected\n'

# Recovery metadata must not be group/world accessible.
chmod 644 "$STATE"
if cyber_state_preflight "$STATE" "$JOURNAL" "$BACKUP_ROOT" "$DEPLOY" "$RESTORE" >/dev/null 2>&1; then
    printf 'FAIL: permissive INSTALL-STATE mode was accepted\n' >&2; exit 1
fi
chmod 600 "$STATE"
printf 'PASS: permissive recovery metadata mode rejected\n'

printf 'ALL RECOVERY STATE TESTS PASSED\n'
