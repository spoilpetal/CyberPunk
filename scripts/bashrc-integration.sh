#!/usr/bin/env bash
# Managed, reversible Bash prompt integration. This file is sourced by install.sh.

cyber_bashrc_validate() {
    local file="$1" begin="$2" end="$3" begin_count end_count
    [[ ! -L "$file" ]] || { printf 'Refusing symlinked .bashrc: %s\n' "$file" >&2; return 1; }
    if [[ -e "$file" && ! -f "$file" ]]; then
        printf '.bashrc is not a regular file: %s\n' "$file" >&2
        return 1
    fi
    [[ -f "$file" ]] || return 0
    begin_count="$(grep -Fxc -- "$begin" "$file" || true)"
    end_count="$(grep -Fxc -- "$end" "$file" || true)"
    if [[ "$begin_count" == 0 && "$end_count" == 0 ]]; then return 0; fi
    [[ "$begin_count" == 1 && "$end_count" == 1 ]] || {
        printf '.bashrc contains incomplete or duplicate Cyberpunk managed-block markers.\n' >&2
        return 1
    }
    awk -v begin="$begin" -v end="$end" '
        $0 == begin { if (inside || seen_begin++) bad=1; inside=1; next }
        $0 == end { if (!inside || seen_end++) bad=1; inside=0; next }
        END { if (inside || bad || seen_begin != 1 || seen_end != 1) exit 1 }
    ' "$file" || {
        printf '.bashrc Cyberpunk managed-block markers are out of order or nested.\n' >&2
        return 1
    }
}

cyber_bashrc_stage() {
    local original="$1" staged="$2" base="$3" begin="$4" end="$5" source_relative="$6"
    cyber_bashrc_validate "$original" "$begin" "$end" || return 1
    mkdir -p -- "$(dirname -- "$staged")" || return 1
    if [[ -f "$original" ]]; then
        awk -v begin="$begin" -v end="$end" '
            $0 == begin { inside=1; next }
            $0 == end { inside=0; next }
            !inside { print }
        ' "$original" > "$base" || return 1
        chmod --reference="$original" "$base" || return 1
    else
        : > "$base" || return 1
    fi
    cat -- "$base" > "$staged" || return 1
    {
        printf '\n%s\n' "$begin"
        printf 'if [[ -r "$HOME/%s" ]]; then\n' "$source_relative"
        printf '    source "$HOME/%s"\n' "$source_relative"
        printf 'fi\n'
        printf '%s\n' "$end"
    } >> "$staged" || return 1
    chmod 600 "$staged" || return 1
    rm -f -- "$base"
}
