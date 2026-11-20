<h1 align="center">Cyberpunk Desktop Installer<sub>Beta</sub></h1>

A curated Arch Linux x86_64 installer for the Cyberpunk Hyprland desktop configuration included in `payload/`. It deploys the supplied Hyprland, Waybar, Wofi, Dunst, Kitty, GTK, icon/cursor, wallpaper, XDG portal, and SDDM-theme files, and installs the packages listed in the manifests.

This is a desktop configuration installer, **not** an Arch OS installer or disk-reset utility. It does not partition disks, format filesystems, install a bootloader, or reinstall Arch.

## Safety and current validation status

- `--plan` is the default and does not install packages or deploy files.
- `--apply` requires the exact confirmation `YES` and sudo authorization.
- Existing managed destination files are backed up before package transactions.
- The installer adds or updates one clearly delimited managed block in `~/.bashrc` to source the Cyberpunk prompt. Other `.bashrc` content is preserved. The original `.bashrc` is backed up and can be restored.
- Existing files at payload destinations are backed up before replacement. Unrelated files and user documents are not targeted.
- The installer deploys the included Hyprland configuration; it does not merge arbitrary changes into that configuration file.
- SDDM theme assets are copied. During `--apply`, the installer explicitly asks whether to enable `sddm.service` at boot. The default is No; declining leaves the current service state unchanged. Choosing Yes runs `sudo systemctl enable sddm.service` after file deployment. It does not start or restart SDDM in the current session.
- Package changes are not reversed by file recovery.
- Recovery uses exact journal/state coverage, original-backup checksum verification, deployment progress, restoration progress, and a complete conflict preflight before changing destinations.
- Backups are retained. Do not delete them until the installed system has been checked and recovery is no longer needed.

The source checks and isolated recovery/Bash-integration tests run in the review environment. **No live package installation, clean-machine boot, Hyprland session, SDDM rendering, or hardware test has been performed.** Do not interpret passing static tests as a guarantee of runtime compatibility.



## Screenshots (Using <a href="https://github.com/zaynkhan100110/CyberShot">CyberShot</a>)

Have a look at CyberPunk Desktop interface and features through the screenshots below.

### Sddm Login

![Sddm login Interface](https://raw.githubusercontent.com/spoilpetal/Picture_Vault/main/CyberPunk/sddm_login.png)


### Main Desktop

![Main Desktop Interface](https://raw.githubusercontent.com/spoilpetal/Picture_Vault/main/CyberPunk/main_desktop.png)


### Woffi application launcher

![Woffi application launcher](https://raw.githubusercontent.com/spoilpetal/Picture_Vault/main/CyberPunk/woffi-application_launcher.png)



### Terminal looks
- [About neochange](#details)

![Terminal looks](https://raw.githubusercontent.com/spoilpetal/Picture_Vault/main/CyberPunk/terminal+neochange+neofetch.png)



### Terminal looks x2
- [About changewall](#details)

![Terminal looks](https://raw.githubusercontent.com/spoilpetal/Picture_Vault/main/CyberPunk/theme+waybar+colors_change_with_changewall.png)



## Requirements

- Arch Linux x86_64 (the bundled Wallust package is x86_64-specific)
- A normal non-root user account with working `sudo`
- Bash, `pacman`, `pacman-conf`, `sha256sum`, `flock`, `find`, `awk`, `sort`, `stat`, `sync`, `grep`, and standard GNU utilities
- A network connection for official repository package installation
- Hyprland 0.55 or newer (the supplied `hyprland.lua` uses Hyprland's Lua configuration interface)
- The package set in `packages/official.txt` and the four bundled archives in `dist/dependencies/`

The installer can be launched from a TTY. The graphical experience itself requires a working Hyprland session and compatible graphics/input hardware. The portal configuration uses GTK as the generic/file-chooser backend and Hyprland for screenshot/screencast requests. Hyprland sets the Wayland desktop/session variables before compositor initialization, allowing its default D-Bus/systemd environment integration to propagate them. Included shortcuts: `SUPER+SHIFT+C` captures a selected region to `~/Pictures/Screenshots` and the clipboard; `SUPER+B` toggles Waybar; `SUPER+M` exits Hyprland.

## Review and install

From the extracted project directory:

```bash
./scripts/verify.sh
./scripts/install.sh --plan
```

Review the complete package/file counts and target paths. The installer replaces files at the exact paths under `payload/home/` and `payload/usr/`; those existing files are backed up first. It also manages the prompt block in `.bashrc`. The apply phase uses `pacman -Syu`, so it performs a full system upgrade as well as installing the listed official packages. Pacman retains its own transaction prompts; review them before accepting. The installer then asks `Enable SDDM at boot? [y/N]`; answer `y` to enable the login manager for future boots or press Enter/answer `n` to leave its current state unchanged. An invalid or unanswered choice stops before installation changes.

Only after reviewing the plan on the target machine, run apply:

```bash
./scripts/install.sh --apply
```

Do not run the installer as root. Do not run it while another installer or recovery operation is active. Keep the project archive and generated backup directory until the desktop has been checked.

## Recovery

Read [docs/RESTORE.md](docs/RESTORE.md). Inspect first:

```bash
./scripts/restore.sh --plan
```

Apply only after reviewing the selected backup and confirming that the current files are expected. Recovery stops before changing anything if a managed destination is ambiguous or has changed unexpectedly.

## Package provenance

The bundle includes four prebuilt Arch package archives. Their SHA-256 hashes are checked against `dist/dependencies/SHA256SUMS`. This detects accidental or local modification relative to the included checksum list; it does not prove publisher authenticity. The archives are unsigned in this bundle. The installer checks `LocalFileSigLevel` before the package phase and refuses to proceed if local package signatures are required; it never weakens pacman signature policy. See [docs/SECURITY-REVIEW.md](docs/SECURITY-REVIEW.md).

## Rebuilding bundled packages

The optional dependency builder needs additional Rajdhani recipe/license inputs that are not included in this archive. See [docs/BUILD-DEPENDENCIES.md](docs/BUILD-DEPENDENCIES.md) before using it.


## Details

- You can change your distro logo (neofetch only now) using `neochange`
  ```bash
  neochange path/to/image
  ```
- You can change your wallpaper + waybar + desktop theme (based on your wallpaper) using `changewall`
  ```bash
  changewall path/to/image
  ```


## Project layout

- `scripts/install.sh` — installer
- `scripts/restore.sh` — file recovery utility
- `scripts/recovery-state.sh` — shared protected-recovery validation
- `scripts/bashrc-integration.sh` — reversible managed Bash prompt integration
- `scripts/build-dependencies.sh` — optional package builder
- `scripts/verify.sh` — static and isolated test runner
- `payload/` — user and system theme/configuration files
- `packages/` — required, official, and bundled package manifests
- `dist/dependencies/` — bundled package archives and checksums
- `tests/` — recovery-state and Bash-integration tests
- `docs/` — operational and review documentation
