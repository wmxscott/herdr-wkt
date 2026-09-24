#!/usr/bin/env bats

load test_helper

setup() {
    common_setup
    make_origin
}

@test "setup clones into .bare and checks out the default branch" {
    mkdir layout && cd layout
    run wkt setup "$ORIGIN"
    [ "$status" -eq 0 ]
    [ "$(last_line)" = "✓ .bare worktree layout ready  main" ]

    [ -d .bare ]
    [ "$(cat .git)" = "gitdir: ./.bare" ]
    [ "$(git config --bool core.bare)" = true ]
    [ "$(git config remote.origin.fetch)" = "+refs/heads/*:refs/remotes/origin/*" ]
    git show-ref --verify --quiet refs/remotes/origin/develop
    [ "$(git -C main branch --show-current)" = main ]
    [ "$(git -C main rev-parse --abbrev-ref '@{upstream}')" = origin/main ]
    [ "$(git symbolic-ref --short refs/remotes/origin/HEAD)" = origin/main ]
}

@test "setup follows a default branch that isn't main or master" {
    rm -rf "$TMP/src" "$TMP/remotes"
    make_origin trunk
    mkdir layout && cd layout
    run wkt setup "$ORIGIN"
    [ "$status" -eq 0 ]
    [ -d trunk ]
    [ "$(git -C trunk branch --show-current)" = trunk ]
}

@test "setup refuses a directory that isn't empty" {
    mkdir layout && cd layout
    touch stray
    run wkt setup "$ORIGIN"
    [ "$status" -eq 1 ]
    contains "$output" "Current directory is not empty."
    [ ! -e .bare ]
}

@test "setup doesn't call herdr" {
    mkdir layout && cd layout
    run wkt setup "$ORIGIN"
    [ "$status" -eq 0 ]
    [ -z "$(herdr_calls)" ]
}
