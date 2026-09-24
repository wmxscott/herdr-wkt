# shellcheck shell=bash
# Shared setup: every test runs in its own temp dir with a scrubbed
# environment, a throwaway HOME and git config, and stub herdr and gh
# commands, so nothing touches a real Herdr session, GitHub or your repos.

bats_require_minimum_version 1.5.0

SCRIPT="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)/bin/herdr-wkt"

common_setup() {
    local name
    for name in $(compgen -e); do
        case $name in
            HERDR_* | GIT_* | GH_* | GITHUB_TOKEN | ZDOTDIR | XDG_* | DEV_DIR | NO_COLOR)
                unset "$name" ;;
        esac
    done

    TMP="$(cd "$BATS_TEST_TMPDIR" && pwd -P)"
    export HOME="$TMP/home"
    mkdir -p "$HOME"
    export GIT_CONFIG_NOSYSTEM=1
    cat >"$HOME/.gitconfig" <<'EOF'
[user]
    name = Test
    email = test@example.com
[init]
    defaultBranch = main
[commit]
    gpgsign = false
[advice]
    detachedHead = false
EOF

    STUB_BIN="$TMP/bin"
    mkdir -p "$STUB_BIN"
    ln -s "$SCRIPT" "$STUB_BIN/herdr-wkt"
    ln -s herdr-wkt "$STUB_BIN/wkt"

    export STUB_HERDR_LOG="$TMP/herdr.log"
    cat >"$STUB_BIN/herdr" <<'EOF'
#!/bin/bash
if env | grep -q '^HERDR_'; then
    echo "stub herdr: HERDR_* leaked into the environment" >&2
    exit 99
fi
printf '%s\n' "$*" >>"$STUB_HERDR_LOG"
if [[ -n ${STUB_HERDR_FAIL:-} ]]; then
    echo '{"error":"server not running"}' >&2
    exit 1
fi
EOF

    export STUB_GH_LOG="$TMP/gh.log"
    cat >"$STUB_BIN/gh" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$STUB_GH_LOG"
if [[ $1 == pr && -n ${STUB_GH_PR:-} ]]; then
    printf '%s\n' "$STUB_GH_PR"
    exit 0
fi
exit 1
EOF
    chmod +x "$STUB_BIN/herdr" "$STUB_BIN/gh"

    export PATH="$STUB_BIN:/usr/bin:/bin:/usr/sbin:/sbin"
    if [[ "$(command -v herdr)" != "$STUB_BIN/herdr" || "$(command -v gh)" != "$STUB_BIN/gh" ]]; then
        echo "refusing to run: herdr or gh doesn't resolve to the stub" >&2
        return 1
    fi

    cd "$TMP" || return 1
}

# make_origin [<default-branch>]: a bare "remote" at $ORIGIN, named
# acme/widget, with the default branch plus 'develop' and 'feature-x'.
make_origin() {
    local default=${1:-main} src="$TMP/src"
    ORIGIN="$TMP/remotes/acme/widget.git"
    git init --quiet -b "$default" "$src"
    git -C "$src" commit --quiet --allow-empty -m "initial"
    git -C "$src" branch develop
    git -C "$src" branch feature-x
    git -C "$src" checkout --quiet develop
    git -C "$src" commit --quiet --allow-empty -m "develop work"
    git -C "$src" checkout --quiet feature-x
    git -C "$src" commit --quiet --allow-empty -m "feature work"
    git -C "$src" checkout --quiet "$default"
    mkdir -p "${ORIGIN%/*}"
    git clone --quiet --bare "$src" "$ORIGIN"
}

# make_layout: a .bare layout of $ORIGIN at $LAYOUT, made by 'setup'.
make_layout() {
    LAYOUT="$TMP/layout"
    mkdir -p "$LAYOUT"
    (cd "$LAYOUT" && herdr-wkt setup "$ORIGIN") >/dev/null 2>&1
}

# make_clone: a normal clone of $ORIGIN at $CLONE.
make_clone() {
    CLONE="$TMP/widget"
    git clone --quiet "$ORIGIN" "$CLONE"
}

rev() { git -C "$1" rev-parse "$2"; }

herdr_calls() { cat "$STUB_HERDR_LOG" 2>/dev/null || true; }

# The last line of $output; macOS's bash 3.2 has no ${lines[-1]}.
# shellcheck disable=SC2154 # bats sets $lines
last_line() { printf '%s\n' "${lines[${#lines[@]}-1]}"; }

# Assertions. Bash 3.2 (macOS) doesn't stop a test on a failing [[ ]] that
# isn't the last command, so string checks go through functions instead.
contains() {
    [[ $1 == *"$2"* ]] && return 0
    printf 'expected to contain: %s\nactual: %s\n' "$2" "$1" >&2
    return 1
}
lacks() {
    [[ $1 != *"$2"* ]] && return 0
    printf 'expected not to contain: %s\nactual: %s\n' "$2" "$1" >&2
    return 1
}
starts_with() {
    [[ $1 == "$2"* ]] && return 0
    printf 'expected to start with: %s\nactual: %s\n' "$2" "$1" >&2
    return 1
}
