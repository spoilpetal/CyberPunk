# Rebuilding bundled dependencies

`scripts/build-dependencies.sh` rebuilds Neofetch, Wallust, Rajdhani, and
Oxanium using pinned recipe fingerprints.

## Required Rajdhani inputs

The review archive does not contain these two local files:

```text
.build/dependencies/ttf-rajdhani/PKGBUILD
.build/dependencies/ttf-rajdhani/OFL.txt
```

The builder checks for them before creating build directories or downloading
recipes. It stops safely if either is absent. These files were excluded from
the supplied archive, so a clean extraction cannot currently rebuild Rajdhani.

Do not invent or substitute a PKGBUILD. Obtain the exact reviewed recipe and
license source, verify their expected SHA-256 values in
`scripts/build-dependencies.sh`, and inspect the recipe before running
`makepkg`. A matching hash establishes byte-for-byte correspondence with the
pinned local fingerprint, not publisher identity.

The prebuilt Rajdhani package is already present in `dist/dependencies/` and
is checked by the installer against `SHA256SUMS`; rebuilding is not required
for installation.
