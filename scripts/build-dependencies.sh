#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$PROJECT_DIR/.build/dependencies"
RECIPE_DIR="$WORK_DIR/verified-recipes"
STAGE_DIR="$WORK_DIR/output-stage"
DIST_DIR="$PROJECT_DIR/dist/dependencies"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ $EUID -ne 0 ]] || fail 'Run as the normal desktop user, not root.'
[[ -f /etc/arch-release ]] || fail 'Arch Linux is required.'

# The Rajdhani build inputs are intentionally not redistributed in the review
# archive. Refuse before creating directories or downloading any recipes.
RAJDHANI_INPUT_DIR="$WORK_DIR/ttf-rajdhani"
[[ -f "$RAJDHANI_INPUT_DIR/PKGBUILD" && -f "$RAJDHANI_INPUT_DIR/OFL.txt" ]] ||
    fail "Rajdhani rebuild inputs are missing. See docs/BUILD-DEPENDENCIES.md; no build was started."

for tool in curl makepkg sha256sum pacman install awk sort; do
    command -v "$tool" >/dev/null 2>&1 || fail "Missing required tool: $tool"
done

declare -A UPSTREAM_HASH=(
    [neofetch]=eb248e48fad5315928a82ebb151ba72d6c673c87a5b43f9391c63966c44e705e
    [wallust]=6241fa3d9c5d8de13e0fd6bc9f179c1dd4b8b96570c3a1c294dc187752f12566
    [ttf-rajdhani]=0322485cfc50e3579b7c38cb85861a0b5df4e8c14f434689b99471fdb9744533
    [ttf-oxanium]=4e1e9b4c0300b48ffe6ac0f67b40023cfd21abe7175b9a5f0af4e3abd3abbe82
)

RAJDHANI_CUSTOM_HASH=f1858e125f31d1ea178e666b64becbe97915ae7d54d50a97c2ae8f39683c7853
RAJDHANI_LICENSE_HASH=f62ef357d3a1c3d27edd35a6e1ba350e8a8d13499797964eeadefbf0b3b15d1f

printf '\nCYBERPUNK DESKTOP — VERIFIED DEPENDENCY BUILDER\n'
printf 'Packages: Neofetch, Wallust, Rajdhani, Oxanium\n'
printf 'Build workspace: %s\n' "$WORK_DIR"
printf 'Output directory: %s\n\n' "$DIST_DIR"
printf 'No packages will be installed by this script.\n'
printf 'Missing build dependencies will stop the build.\n'
printf 'Build recipes execute code as your normal user; review remains essential.\n'
printf 'Only the four approved release packages will enter the final bundle.\n\n'

read -r -p 'Verify recipes and rebuild all four packages? Type YES: ' answer
[[ "$answer" == YES ]] || {
    printf '%s\n' 'Cancelled; no build started.'
    exit 0
}

mkdir -p "$RECIPE_DIR" "$STAGE_DIR" "$DIST_DIR"

# Clear only known generated release archives from the staging directory.
for pkg in neofetch wallust ttf-rajdhani ttf-oxanium; do
    find "$STAGE_DIR" -maxdepth 1 -type f \
        -name "$pkg-[0-9]*.pkg.tar.zst" -delete
done

for pkg in neofetch wallust ttf-rajdhani ttf-oxanium; do
    printf '\n===== VERIFYING %s =====\n' "$pkg"
    recipe="$RECIPE_DIR/$pkg.PKGBUILD"

    curl --fail --silent --show-error --location \
        "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=$pkg" \
        -o "$recipe" ||
        fail "Could not download upstream $pkg recipe."

    actual_hash="$(sha256sum "$recipe" | awk '{print $1}')"
    [[ "$actual_hash" == "${UPSTREAM_HASH[$pkg]}" ]] ||
        fail "$pkg upstream recipe fingerprint mismatch."

    printf 'Upstream fingerprint verified: %s\n' "$pkg"

    if [[ "$pkg" == ttf-rajdhani ]]; then
        custom="$WORK_DIR/ttf-rajdhani/PKGBUILD"
        license="$WORK_DIR/ttf-rajdhani/OFL.txt"

        [[ -f "$custom" && -f "$license" ]] ||
            fail 'Reviewed Rajdhani custom recipe or OFL license is missing.'

        actual_hash="$(sha256sum "$custom" | awk '{print $1}')"
        [[ "$actual_hash" == "$RAJDHANI_CUSTOM_HASH" ]] ||
            fail 'Rajdhani custom recipe fingerprint mismatch.'

        actual_hash="$(sha256sum "$license" | awk '{print $1}')"
        [[ "$actual_hash" == "$RAJDHANI_LICENSE_HASH" ]] ||
            fail 'Rajdhani OFL license fingerprint mismatch.'

        printf '%s\n' 'Custom Rajdhani recipe and OFL license verified.'
        printf '%s\n' 'The upstream install hook will not be downloaded or used.'
    else
        install -m 0644 "$recipe" "$WORK_DIR/$pkg/PKGBUILD"
    fi
done

printf '\nAll upstream and custom recipe fingerprints verified.\n'

for pkg in ttf-rajdhani ttf-oxanium neofetch wallust; do
    printf '\n========== BUILDING %s ==========\n' "$pkg"

    marker="$STAGE_DIR/$pkg.started"
    touch "$marker"

    (
        cd "$WORK_DIR/$pkg"
        makepkg --cleanbuild --noconfirm
    ) || fail "Build failed for $pkg."

    mapfile -t built_packages < <(
        find "$WORK_DIR/$pkg" -maxdepth 1 -type f \
            -name "$pkg-*.pkg.tar.zst" \
            ! -name "$pkg-debug-*.pkg.tar.zst" \
            -newer "$marker" -print
    )

    ((${#built_packages[@]} == 1)) ||
        fail "Expected exactly one newly built release package for $pkg."

    package="${built_packages[0]}"
    actual_name="$(pacman -Qp "$package" | awk 'NR == 1 {print $1}')"

    [[ "$actual_name" == "$pkg" ]] ||
        fail "Package identity mismatch: expected $pkg, got $actual_name."

    install -m 0644 "$package" "$STAGE_DIR/"
    rm -f "$marker"

    printf 'Verified release package: %s\n' "$(basename -- "$package")"
done

printf '\nAll four packages built and inspected successfully.\n'
printf 'Updating final dependency bundle...\n'

# Remove only the four known release package names and the known Wallust
# debug artifact. Preserve unrelated files in the distribution directory.
for pattern in \
    'neofetch-[0-9]*.pkg.tar.zst' \
    'wallust-[0-9]*.pkg.tar.zst' \
    'ttf-rajdhani-[0-9]*.pkg.tar.zst' \
    'ttf-oxanium-[0-9]*.pkg.tar.zst' \
    'wallust-debug-*.pkg.tar.zst'; do
    find "$DIST_DIR" -maxdepth 1 -type f -name "$pattern" -delete
done
rm -f -- "$DIST_DIR/SHA256SUMS"

# Copy exactly one staged release archive for each approved package.
for pkg in neofetch wallust ttf-rajdhani ttf-oxanium; do
    mapfile -t staged < <(
        find "$STAGE_DIR" -maxdepth 1 -type f \
            -name "$pkg-[0-9]*.pkg.tar.zst" -print
    )
    (("${#staged[@]}" == 1)) ||
        fail "Expected exactly one staged release archive for $pkg."
    install -m 0644 -- "${staged[0]}" "$DIST_DIR/"
done

(
    cd "$DIST_DIR"
    sha256sum ./*.pkg.tar.zst | sort > SHA256SUMS
    sha256sum --check SHA256SUMS
)

printf '\nSUCCESS: Four release packages are ready.\n'
printf 'Final bundle: %s\n' "$DIST_DIR"
du -sh "$DIST_DIR"
printf '%s\n' 'No package was installed on this system.'
