#!/usr/bin/env bats

load test_helper

setup() {
    common_setup
    make_origin
    make_clone
    cd "$CLONE" || return 1
}

# Everything git status can report, including ignored files.
status_all() { git -C "$1" status --porcelain=v1 --ignored --untracked-files=all; }

@test "adopt turns a clone into a .bare layout" {
    run wkt adopt
    [ "$status" -eq 0 ]
    contains "$output" "✓ .bare worktree layout ready  main"
    contains "$output" "run: cd main"

    [ -d .bare ]
    [ "$(cat .git)" = "gitdir: ./.bare" ]
    [ "$(git config --bool core.bare)" = true ]
    [ "$(ls -A)" = "$(printf '.bare\n.git\nmain')" ]
    [ "$(git -C main branch --show-current)" = main ]
    [ "$(git -C main rev-parse --abbrev-ref '@{upstream}')" = origin/main ]
    [ "$(git -C main rev-parse --git-common-dir)" = "$CLONE/.bare" ]
    [ -z "$(status_all main)" ]
    [ -z "$(herdr_calls)" ]
}

@test "adopt keeps staged, unstaged, untracked and ignored files" {
    printf 'one\n' >tracked && printf 'ignored.log\n' >.gitignore
    git add tracked .gitignore && git commit --quiet -m "files"
    printf 'two\n' >>tracked
    printf 'new\n' >staged && git add staged
    printf 'x\n' >untracked
    printf 'y\n' >ignored.log
    mkdir -p nested/dir && printf 'z\n' >nested/dir/deep
    before="$(status_all .)"

    run wkt adopt
    [ "$status" -eq 0 ]
    [ "$(status_all main)" = "$before" ]
    [ "$(cat main/tracked)" = "$(printf 'one\ntwo')" ]
    [ "$(git -C main diff --cached --name-only)" = staged ]
}

@test "adopt names the worktree after the current branch, nesting slashes" {
    git checkout --quiet -b feat/login
    run wkt adopt
    [ "$status" -eq 0 ]
    [ "$(git -C feat/login branch --show-current)" = feat/login ]
    [ ! -e main ]
}

@test "adopt copes with a tracked folder named like the branch" {
    mkdir main && printf 'm\n' >main/file
    git add main && git commit --quiet -m "a main folder"
    run wkt adopt
    [ "$status" -eq 0 ]
    [ "$(cat main/main/file)" = m ]
    [ -z "$(status_all main)" ]
}

@test "adopt repairs linked worktrees made before" {
    git worktree add --quiet "$TMP/side" develop
    run wkt adopt
    [ "$status" -eq 0 ]
    [ "$(git -C "$TMP/side" branch --show-current)" = develop ]
    [ "$(git -C "$TMP/side" rev-parse --git-common-dir)" = "$CLONE/.bare" ]
    [ "$(cat .git)" = "gitdir: ./.bare" ]
}

@test "wkt new after adopt puts worktrees next to .bare" {
    wkt adopt >/dev/null
    cd main
    run wkt new -b topic
    [ "$status" -eq 0 ]
    [ "$(git -C "$CLONE/topic" branch --show-current)" = topic ]
}

@test "adopt refuses from a subfolder" {
    mkdir sub && cd sub
    run wkt adopt
    [ "$status" -eq 1 ]
    contains "$output" "Run 'wkt adopt' from the top of the clone."
    [ -d "$CLONE/.git" ]
}

@test "adopt refuses a .bare layout" {
    make_layout
    cd "$LAYOUT"
    run wkt adopt
    [ "$status" -eq 1 ]
    contains "$output" "already a .bare layout"
    cd "$LAYOUT/main"
    run wkt adopt
    [ "$status" -eq 1 ]
    contains "$output" "already a .bare layout"
}

@test "adopt refuses a linked worktree" {
    git worktree add --quiet "$TMP/side" develop
    cd "$TMP/side"
    run wkt adopt
    [ "$status" -eq 1 ]
    contains "$output" "linked worktree or a submodule"
}

@test "adopt refuses a detached HEAD" {
    git checkout --quiet --detach
    run wkt adopt
    [ "$status" -eq 1 ]
    contains "$output" "Detached HEAD."
    [ -d .git ]
}

@test "adopt refuses an operation in progress" {
    git rev-parse HEAD >.git/MERGE_HEAD
    run wkt adopt
    [ "$status" -eq 1 ]
    contains "$output" "is in progress"
    [ -d .git ]
}

@test "adopt refuses submodules" {
    touch .gitmodules
    run wkt adopt
    [ "$status" -eq 1 ]
    contains "$output" "submodules aren't supported"
    [ -d .git ]
}

@test "adopt refuses when .bare exists" {
    mkdir .bare
    run wkt adopt
    [ "$status" -eq 1 ]
    contains "$output" "'.bare' already exists."
    [ -d .git ]
}

@test "adopt refuses a branch with no commits" {
    git init --quiet "$TMP/empty"
    cd "$TMP/empty"
    run wkt adopt
    [ "$status" -eq 1 ]
    contains "$output" "has no commits yet"
}
