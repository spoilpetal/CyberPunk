# Cyberpunk Desktop Installer — Recovery and Restoration

## Safety and scope

The installer creates timestamped backups under:

`~/.local/state/cyberpunk-desktop-installer/backups/`

Each new-format backup contains:

- `home/` — original user files replaced by the installer, including the original `.bashrc` if it existed.
- `system/` — original system files replaced by the installer.
- `FILE-JOURNAL` — exact managed destination list and original existence flags.
- `INSTALL-STATE` — installed and original SHA-256 checksums for every journal entry.
- `DEPLOY-PROGRESS` — files copied and checksum-verified successfully.
- `RESTORE-PROGRESS` — files restored and checksum-verified successfully.
- `INSTALL-IN-PROGRESS` — phase marker for an interrupted installation, when present.

The restore utility restores recorded files only. It does not uninstall or downgrade packages, reverse package-manager transactions (including the full system upgrade performed by `pacman -Syu`), restore service state, change partitions, format disks, or restore unrelated personal files.

Do not delete or modify a backup while recovery may still be needed.

## Concurrent operation protection

The installer and restore utility share an operation lock at:

`~/.local/state/cyberpunk-desktop-installer/operation.lock`

Only one installation or recovery operation can run at a time. Restore `--plan` remains available without acquiring the lock. Do not manually remove the lock to bypass this protection.

## Inspect a recovery plan

From the project directory:

```bash
./scripts/restore.sh --plan
```

The utility checks for an interrupted installation first. If none is found, it uses the latest successful installation backup. To inspect a particular backup:

```bash
./scripts/restore.sh --plan /path/to/backup
```

Plan mode is read-only. It checks the journal and target path shape and reports whether checksum-state files are present. Full checksum, backup-integrity, progress, and conflict validation runs during `--apply` after confirmation and sudo authorization; do not treat the plan as proof that apply will pass.

## Restore files

After reviewing the plan:

```bash
./scripts/restore.sh --apply
```

For a specific backup:

```bash
./scripts/restore.sh --apply /path/to/backup
```

The utility asks for the exact confirmation `YES`. It obtains sudo authorization before changing any user or system file. It then validates all state records, every original backup checksum, every progress record, and every managed destination before starting restoration.

Existing files are restored from their backups. Files that did not exist before installation are removed only if the installed version is still present and verified as deployed. The original `.bashrc` is restored in full; if `.bashrc` did not exist before installation, the managed `.bashrc` created by the installer is removed.

Restoration runs in reverse journal order. Each restored file is copied through a temporary file in the destination directory, checksum-verified, and renamed into place. The backup is retained.

## All-or-nothing conflict policy

If any managed destination is neither:

- the original file state, or
- the exact installed payload with a matching `DEPLOY-PROGRESS` entry,

the whole restore is refused before any destination is changed. All conflicting paths are reported. This includes user-edited files, symlinked paths, partial copies, and files whose deployment completion was not recorded.

There is no conflict-bypass or force option. Preserve the backup and current files, inspect the conflicts separately, and make a deliberate recovery decision. Do not edit checksum/progress manifests to force restoration.

## Interrupted deployment and restoration

Deployment progress is recorded only after an atomic same-directory copy/rename and destination checksum verification. If a crash occurs after the rename but before its progress entry is recorded, the destination is treated as ambiguous and recovery stops rather than assuming it is safe to overwrite.

Restoration progress is recorded only after the original checksum (or original absence) is verified. On retry:

- A destination matching the original state is already restored and is not copied again.
- A destination matching the installed checksum is eligible for restoration only if its deployment record exists and it has not already been recorded as restored.
- A partial or unexpected destination is a conflict.
- If a file was previously recorded as restored and later changes, it is a conflict.

A power loss can leave a temporary `.cyberarch-deploy.*` or `.cyberarch-restore.*` file in a destination directory. These temporary files are not treated as managed destinations and are not automatically deleted by recovery. Inspect them before manual cleanup.

## Interrupted installation phases

The marker records one of these phases:

- `preparing` — backups and state records were being prepared; deployment had not begun.
- `packages` — package operations may have started; file deployment had not begun.
- `deploying` — file deployment may have been interrupted.

For `preparing` and `packages`, file restoration is not required because deployment had not begun. Package changes are not reversed automatically. The package phase uses `pacman -Syu` and keeps pacman's own prompts enabled so replacements/conflicts can be reviewed. After confirming no installer process is running, `--clear-marker` can clear a valid `preparing` or `packages` marker after exact confirmation. It also removes the generated temporary `.bashrc` staging directory, but retains the journal and all original backups:

```bash
./scripts/restore.sh --clear-marker
```

This does not delete the journal or original backups. It refuses `deploying` markers.

## Legacy backups

Backups without `INSTALL-STATE`, `DEPLOY-PROGRESS`, or `RESTORE-PROGRESS` remain preserved. Protected `--apply` refuses them because their deployment/restoration state cannot be proven. There is no force override. Plan mode can still inspect their journal.

## Important limitations

- Package installation or upgrades are not reversed.
- Static checks do not simulate every power failure, process kill, filesystem race, or storage failure.
- Atomic rename reduces partial-file exposure but cannot make a multi-file restore a single atomic transaction.
- Checksum validation is content-based; it does not prove publisher authenticity or detect every metadata-only change.
- Race conditions between path preflight and filesystem operations cannot be completely eliminated by shell scripts.
- System-file restoration requires working sudo authorization.
- A successful file restoration does not guarantee that every package or desktop component has returned to its previous state.

Keep backups until the restored system has been inspected and verified.
