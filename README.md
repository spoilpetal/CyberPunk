
<h1 align="center">CyberPunk</h1>

A curated Arch Linux desktop configuration installer that deploys the CyberPunk desktop environment and its associated tools.

**Status:** Beta Release

CyberPunk automates the setup of a customized desktop environment built around Hyprland, Waybar, Wofi, Dunst, Kitty, GTK themes, icons, cursors, wallpapers, XDG portals, and an SDDM login theme.

---

## ⚠️ Important Installation Notice

> **This installer is intended ONLY for a fresh Arch Linux installation.**

The recommended starting point is:

- A fresh Arch Linux installation using a pure TTY environment, or
- A fresh Arch Linux installation with a minimal Hyprland setup.

**Do not run this installer on an existing, customized desktop installation.**

The installer installs Hyprland and its associated desktop components, then deploys CyberPunk configuration files to their designated system and user locations. Existing files at those managed destinations may be replaced.

Although the installer creates backups of managed files, those backups do not make it suitable for preserving an existing customized desktop environment.

### Supported system

- Arch Linux x86_64.
- Fresh installation recommended.
- Other Arch-based distributions and derivatives have not been tested and are not officially supported.

This project is a desktop configuration installer, **not an operating system installer**. It does not partition disks, format drives, install a bootloader, or reinstall Arch Linux.

---

## Screenshots

The following screenshots show CyberPunk running on the developer's own Arch Linux system.

### SDDM Login Screen

![CyberPunk SDDM Login Screen](https://raw.githubusercontent.com/spoilpetal/Picture_Vault/main/CyberPunk/sddm_login.png)

### Main Desktop

![CyberPunk Main Desktop](https://raw.githubusercontent.com/spoilpetal/Picture_Vault/main/CyberPunk/main_desktop.png)

### Application Launcher

![Wofi Application Launcher](https://raw.githubusercontent.com/spoilpetal/Picture_Vault/main/CyberPunk/woffi-application_launcher.png)

### Terminal, neochange and Neofetch

![Terminal with neochange and Neofetch](https://raw.githubusercontent.com/spoilpetal/Picture_Vault/main/CyberPunk/terminal+neochange+neofetch.png)

### Dynamic Wallpaper and Waybar Theme

![Changewall dynamic wallpaper and Waybar theme](https://raw.githubusercontent.com/spoilpetal/Picture_Vault/main/CyberPunk/theme+waybar+colors_change_with_changewall.png)

Screenshots were captured using [CyberShot](https://github.com/zaynkhan100110/CyberShot).

---

## Features

- Automated Hyprland desktop environment setup.
- Waybar configuration and styling.
- Wofi application launcher.
- Dunst notification daemon configuration.
- Kitty terminal configuration.
- GTK themes, icons, and cursor themes.
- Wallpaper configuration.
- Dynamic wallpaper and Waybar color customization through `changewall`.
- Terminal logo customization through `neochange`.
- XDG desktop portal configuration.
- SDDM login screen theme deployment.
- Package installation through Pacman.
- Managed file backups before deployment.
- Installation planning mode.
- Installation recovery support.
- Deployment and restoration tracking.

---

## Requirements

Before running the installer, make sure you have:

- A fresh Arch Linux x86_64 installation.
- A normal user account with `sudo` privileges.
- An active internet connection.
- Standard Arch Linux command-line utilities.
- Sufficient disk space for the desktop components and dependencies.

The included configuration targets Hyprland 0.55 or newer.

The package list is maintained in:

```text
packages/official.txt
```

Bundled dependencies are stored in:

```text
dist/dependencies/
```

The included XDG portal configuration covers GTK file chooser integration and Hyprland screenshot/screencast functionality.

---

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/spoilpetal/CyberPunk.git
cd CyberPunk
```

### 2. Verify the installation files

```bash
./scripts/verify.sh
```

### 3. Review the installation plan

The installer uses planning mode by default. This does not apply system changes.

```bash
./scripts/install.sh --plan
```

Review the planned operations and deployment destinations before proceeding.

Pay particular attention to files under:

```text
payload/home/
payload/usr/
```

### 4. Apply the installation

```bash
./scripts/install.sh --apply
```

The installer requires the exact confirmation:

```text
YES
```

It will request the necessary privileges through `sudo`.

During installation:

- Required packages are installed through Pacman.
- Existing managed files are backed up.
- CyberPunk configuration files are deployed.
- The installer may ask whether to enable SDDM at boot.

**SDDM is not enabled automatically.**

If you choose Yes, the installer runs:

```bash
sudo systemctl enable sddm.service
```

This enables SDDM for future boots. It does not start or restart the current graphical session.

### Important package note

The installation may perform a full system upgrade through:

```bash
sudo pacman -Syu
```

Review Pacman prompts carefully before accepting package changes.

---

## Safety and Validation

CyberPunk includes several safeguards to reduce the risk of unintended changes.

### Planning mode

The default installation mode is non-destructive. It displays the planned operations without applying them.

```bash
./scripts/install.sh --plan
```

### Explicit confirmation

Applying changes requires:

```bash
./scripts/install.sh --apply
```

The installer also requires the exact confirmation `YES`.

### Managed file backups

Before replacing managed files, the installer creates backups.

The backup process covers the exact deployment destinations rather than indiscriminately copying entire system directories.

### Bash configuration handling

The installer manages its own designated prompt block in `.bashrc`.

It preserves the remaining contents of the file and backs up the original `.bashrc` before modifying it.

### Configuration deployment

The included Hyprland configuration is deployed to its managed destination. It is not automatically merged with an existing customized Hyprland configuration.

SDDM theme assets are copied to their designated locations.

### Recovery support

The recovery mechanism uses installation state and deployment records to track:

- Managed file destinations.
- Backup locations.
- File checksums.
- Deployment progress.
- Restoration progress.
- Recovery conflicts.

It performs conflict checks before restoration.

**Keep the generated backups until you are certain that the installation is working correctly.**

### Package changes

File recovery does not automatically reverse Pacman package installations or system upgrades.

---

## Testing Status

CyberPunk has been successfully tested on the developer's own Arch Linux system, and the installation was confirmed to work in that environment.

Additional source checks and isolated recovery and Bash integration tests have also been performed.

However, the following have not been comprehensively tested:

- Multiple clean Arch Linux installations.
- Arch Linux derivatives.
- Different hardware configurations.
- Every graphics and input-device combination.
- Every possible SDDM and Hyprland configuration.

Successful testing on one system does not guarantee compatibility with every Arch Linux installation.

---

## Customization Tools

CyberPunk includes two small customization utilities.

### neochange

`neochange` changes the distribution logo displayed by the terminal system-information utility.

Usage:

```bash
neochange path/to/image
```

Example:

```bash
neochange ~/Pictures/my-logo.png
```

### changewall

`changewall` changes the desktop wallpaper and updates the dynamic desktop and Waybar theme based on the selected wallpaper.

Usage:

```bash
changewall path/to/image
```

Example:

```bash
changewall ~/Pictures/wallpaper.jpg
```

The wallpaper and theme colors are updated together to maintain a consistent desktop appearance.

---

## Cyber Project Collection (Don't get idea about `CS`)

CyberPunk is part of a collection of independent Cyber projects.

### 1. CyberPunk

**Repository:** https://github.com/spoilpetal/CyberPunk

The Arch Linux desktop configuration and installation project. It provides an automated way to deploy the CyberPunk Hyprland desktop environment.

### 2. CyberClip Lite

**Repository:** https://github.com/spoilpetal/CyberClip_lite

A lightweight project in the CyberClip clipboard utility collection.

### 3. CyberClip

**Repository:** https://github.com/spoilpetal/CyberClip

A clipboard utility project in the Cyber software collection.

### 4. CyberShot

**Repository:** https://github.com/zaynkhan100110/CyberShot

A screenshot utility for Linux desktop environments.

### 5. CyberSettings

**Repository:** https://github.com/zaynkhan100110/CyberSettings

A Linux system settings utility project.

### 6. CyberNotes

**Repository:** https://github.com/spoilpetal/CyberNotes

A note-taking project in the Cyber software collection.

---

## Project Structure

The repository is organized into separate directories for installation scripts, configuration payloads, packages, dependencies, tests, and documentation.

```text
CyberPunk/
├── scripts/
│   ├── install.sh
│   └── verify.sh
├── payload/
│   ├── home/
│   └── usr/
├── packages/
│   └── official.txt
├── dist/
│   └── dependencies/
├── tests/
├── docs/
│   ├── RESTORE.md
│   ├── SECURITY-REVIEW.md
│   └── BUILD-DEPENDENCIES.md
└── README.md
```

The exact repository contents may evolve as the project develops.

---

## Recovery and Documentation

Additional technical documentation is available in the repository:

| Document | Description |
|---|---|
| `docs/RESTORE.md` | Recovery and restoration instructions |
| `docs/SECURITY-REVIEW.md` | Security review notes |
| `docs/BUILD-DEPENDENCIES.md` | Dependency build information |

Refer to these documents before performing manual recovery or modifying managed installation files.

---

## Package Provenance

The installer uses the package definitions maintained in `packages/official.txt` and the bundled dependencies under `dist/dependencies/`.

Review the package list and bundled dependency files before installation.

Some bundled package build inputs may not be included in the repository. For example, the Rajdhani package recipe and its original license inputs are not currently provided as a complete reproducible build source.

---

## Disclaimer

CyberPunk is currently a beta project.

It has been tested successfully on the developer's own Arch Linux system. However, compatibility with other installations, hardware, and Arch-based distributions is not guaranteed.

The installer modifies system and user configuration files. Read the installation plan, understand the destinations, and retain backups before applying changes.

**Use it only on a fresh Arch Linux installation.**

---

## License

See the repository's license file for licensing information.
