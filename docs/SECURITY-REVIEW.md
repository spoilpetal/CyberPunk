# Security and verification notes

## Current implementation safeguards

- Installer defaults to plan-only; apply requires an explicit `YES` confirmation.
- Package manifests are parsed and checked for uniqueness, disjointness, and exact coverage.
- Bundled package checksums are verified before package installation.
- Payload rejects symlinks and special file types.
- Existing destinations are backed up before package transactions or deployment.
- `.bashrc` is modified only through a single clearly delimited managed block. Existing content outside the block is retained, malformed/duplicate markers are refused, and the original file is backed up.
- The shared recovery validator requires exact `FILE-JOURNAL`/`INSTALL-STATE` coverage, validates original-backup checksums, checks deployment/restoration progress, validates private state-file ownership/modes, rejects symlinked destination components, and preflights every destination before mutation.
- Deployment and restoration use same-directory temporary files, checksum verification, and rename. Progress is recorded only after verification.
- Conflicts stop the entire restore before any managed file is changed. No force/bypass option exists.
- Installer and restore operations share a lock.
- SDDM boot enablement is an explicit `--apply` opt-in. The default/No choice leaves the current service state unchanged; Yes runs `systemctl enable sddm.service` after file deployment. The installer does not start, restart, or disable SDDM. It does not alter disk or partition state.
- The user portal preference file selects GTK for generic/file-chooser portals and Hyprland for screenshot/screencast. Hyprland sets desktop/session environment variables before compositor initialization.

The dependency builder executes PKGBUILD code through `makepkg`. Inspect recipes and sources before use. A matching local fingerprint establishes byte-for-byte correspondence with the pinned fingerprint, not publisher identity.

## Installation and recovery limits

- The official package phase runs `pacman -Syu`, so it can upgrade the entire system. File recovery does not reverse package transactions or system upgrades.
- The recovery process is not a filesystem-wide atomic transaction. A multi-file operation can be interrupted after some files have been restored; progress records make safe retries possible where the resulting content is verifiable.
- A crash between an atomic file rename and its progress-record append is treated conservatively as a conflict.
- A crash can leave hidden `.cyberarch-deploy.*` or `.cyberarch-restore.*` temporary files beside destinations; these are not automatically removed.
- Checksums cover file contents, not every metadata property.
- TOCTOU races cannot be eliminated completely in Bash.
- Legacy backups without the new state/progress files remain preserved but protected apply is refused.
- SDDM theme files are deployed. SDDM service enablement is controlled by the explicit interactive choice during `--apply`; theme configuration and the current running session are not changed.
- The installer manages a `.bashrc` prompt block; it does not replace the user's whole `.bashrc`.

## Runtime validation still outstanding

The supplied Hyprland configuration requires the Lua configuration interface introduced in Hyprland 0.55. A real clean Arch test is still required for:

- Package availability and dependency resolution against the target Arch mirrors at install time.
- Hyprland Lua configuration parsing and session startup on the exact target Hyprland version.
- Waybar, Wofi, Dunst, Kitty, Wallust, and `awww` runtime behavior.
- Multi-monitor, laptop battery, audio, network, suspend/resume, and graphics-driver behavior.
- SDDM theme rendering and boot/login behavior on the target hardware.
- Interrupted package, deployment, automatic rollback, and manual restore scenarios on a disposable system.

