# Source review report

## Scope

The supplied `Cyberpunk-Desktop-Installer-current.tar.gz` was extracted and reviewed. The work focused on recovery integrity, deployment interruption handling, `.bashrc` prompt integration, test coverage, and operational documentation. The project remains a Hyprland-oriented Arch desktop configuration installer, not a full OS installer.

## Changes made in this revision

1. **Exact recovery coverage:** `INSTALL-STATE` must exactly match every `FILE-JOURNAL` entry. Missing, extra, duplicate, malformed, or traversal entries are refused.
2. **Original backup integrity:** every original backup file is SHA-256 checked against `INSTALL-STATE` before restoration. Unexpected backup files for originally absent destinations are refused.
3. **Private recovery metadata:** backup root and state/journal/progress files are checked for expected ownership and restrictive permissions.
4. **Deployment progress:** `DEPLOY-PROGRESS` records a file only after same-directory staging, checksum verification, rename, and destination checksum verification.
5. **Restoration progress:** `RESTORE-PROGRESS` records a file only after the original checksum or original absence is verified. Previously restored files that later change are conflicts.
6. **All-or-nothing conflict preflight:** all current destinations are checked before the first restore mutation. Any unexpected content, unrecorded deployment, partial copy, or unsafe path stops the operation.
7. **Retry-safe file replacement:** restoration stages backup content in the destination directory, verifies it, and renames it into place. This reduces exposure to partial destination writes.
8. **Automatic rollback:** installer rollback uses the same strict shared preflight and records each verified restoration. It obtains sudo before changing any user or system file.
9. **Managed `.bashrc` integration:** installer adds/updates a bounded Cyberpunk prompt block and preserves all content outside that block. It backs up the original `.bashrc`; malformed marker states are refused.
10. **Fresh-user shell setup:** a new `.bashrc` is created only when none exists, and sources the shipped prompt script from the Cyberpunk theme directory.
11. **Shell and desktop fixes:** added the CyberShot screenshot helper, corrected the wallpaper-border helper path, removed a duplicate Waybar startup race, and added Dunst/Waybar helpers plus early Hyprland session environment variables.
12. **Portal/audio setup:** added `pipewire-pulse`, the GTK portal backend, and a user portal preference file for GTK file chooser plus Hyprland screenshot/screencast.
13. **Package safety:** official repository installation now uses `pacman -Syu` to avoid an unsupported partial upgrade; the plan explicitly warns that this upgrades the whole system. Removed the unused Qt5 Quick Controls package from the manifests and added a preflight that refuses unsigned local archives when pacman requires local signatures.
14. **Tests and docs:** added isolated tests for journal/state coverage, backup tampering, deployment ambiguity, restore retry, post-restore edits, symlinked parents, managed Bash block behavior, and the SDDM opt-in prompt.

## Checks performed in this review environment

- Bash syntax checks for installer, restore, shared recovery helpers, Bash integration helper, tests, and shipped shell scripts.
- Package manifest uniqueness, disjointness, and exact coverage checks.
- SHA-256 verification of all four bundled package archives.
- Payload file-type checks (regular files/directories only).
- Recovery-state test suite passed in an isolated temporary home/backup tree.
- Bash integration test suite passed against temporary `.bashrc` files.
- Static project checks run by `scripts/verify.sh`.
- `restore.sh --apply` was exercised under an unprivileged test account against a synthetic two-file backup: a conflict changed zero files, a clean retry restored both files, and a repeated restore completed safely.

## Not claimed as tested

- No package was installed and no live installer `--apply` was run.
- No live automatic rollback or manual restore was executed against an actual Arch installation; the manual restore integration test used a synthetic backup tree under an unprivileged account.
- No power-loss/process-kill test was run against real filesystems.
- No Hyprland session was launched and no Lua runtime parser was run. The configuration targets Hyprland 0.55+ Lua configuration, but the exact runtime API behavior remains untested.
- SDDM QML was not rendered. The installer can now explicitly enable `sddm.service` at boot when the user answers Yes; this choice and the resulting boot behavior were not exercised on a live Arch installation.
- No multi-monitor, laptop, audio, network, suspend/resume, or GPU testing was performed.
- Bundled package archives are unsigned; their included checksums do not prove publisher authenticity.

## Remaining project limitations

- This bundle is the Cyberpunk Hyprland-oriented edition. It does not contain a separate mouse-oriented CyberNoob edition.
- It is not a disk reset/reinstallation utility and does not install Arch from scratch.
- It only enables SDDM at boot when the user explicitly opts in; it does not start or restart the current session display manager or reverse package transactions.
- The optional dependency builder still requires the excluded reviewed Rajdhani PKGBUILD and OFL inputs described in `docs/BUILD-DEPENDENCIES.md`.
- Runtime compatibility must be confirmed on a disposable clean Arch installation before use on a primary machine.

## Recommendation

Run `scripts/verify.sh`, then `scripts/install.sh --plan` on the target Arch machine. Inspect the plan and package provenance. Use `--apply` only after a separate recovery strategy exists and the user accepts that package changes are not rolled back by file restoration. Keep every backup until the new desktop has been validated.
