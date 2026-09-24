#!/usr/bin/env bats

load test_helper

setup() {
    common_setup
    make_origin
    make_layout
    cd "$LAYOUT/main" || return 1
    wkt new -b topic >/dev/null 2>&1
    : >"$STUB_HERDR_LOG"
    cd "$LAYOUT/topic" || return 1
}

@test "renames the branch and the directory" {
    head="$(rev . HEAD)"
    run wkt rename -b better
    [ "$status" -eq 0 ]
    [ ! -e "$LAYOUT/topic" ]
    [ "$(git -C "$LAYOUT/better" branch --show-current)" = better ]
    [ "$(rev "$LAYOUT/better" HEAD)" = "$head" ]
    run git -C "$LAYOUT" show-ref --verify --quiet refs/heads/topic
    [ "$status" -ne 0 ]
    [ "$(git -C "$LAYOUT" worktree list --porcelain | grep -c "^worktree $LAYOUT/better$")" -eq 1 ]
}

@test "tells herdr about the new path, labelled with the new branch" {
    run wkt rename -b better
    [ "$status" -eq 0 ]
    [ "$(herdr_calls)" = "worktree open --cwd $LAYOUT/.bare --path $LAYOUT/better --label better --focus" ]
    contains "$output" "✓ topic → better  $LAYOUT/better  Herdr workspace updated"
    contains "$output" "run: cd $LAYOUT/better"
}

@test "-n sets the herdr label" {
    run wkt rename -b better -n "Nicer name"
    [ "$status" -eq 0 ]
    [ "$(herdr_calls)" = "worktree open --cwd $LAYOUT/.bare --path $LAYOUT/better --label Nicer name --focus" ]
}

@test "renames the branch on origin when it was pushed" {
    git push --quiet -u origin topic
    run wkt rename -b better
    [ "$status" -eq 0 ]
    git -C "$ORIGIN" show-ref --verify --quiet refs/heads/better
    run git -C "$ORIGIN" show-ref --verify --quiet refs/heads/topic
    [ "$status" -ne 0 ]
    [ "$(git -C "$LAYOUT/better" rev-parse --abbrev-ref '@{upstream}')" = origin/better ]
    starts_with "$(cat "$STUB_GH_LOG")" "pr view topic"
    lacks "$(cat "$STUB_GH_LOG")" "api"
}

@test "leaves origin alone when the branch was never pushed" {
    run wkt rename -b better
    [ "$status" -eq 0 ]
    run git -C "$ORIGIN" show-ref --verify --quiet refs/heads/better
    [ "$status" -ne 0 ]
    [ ! -e "$STUB_GH_LOG" ]
}

@test "open PR without a terminal: aborts and changes nothing" {
    git push --quiet -u origin topic
    STUB_GH_PR=$'12\tOPEN\thttps://example.invalid/pull/12' run wkt rename -b better </dev/null
    [ "$status" -eq 1 ]
    contains "$output" "PR #12 is open for 'topic'"
    contains "$output" "Nothing was changed."
    [ -d "$LAYOUT/topic" ]
    [ "$(git -C "$LAYOUT/topic" branch --show-current)" = topic ]
    git -C "$ORIGIN" show-ref --verify --quiet refs/heads/topic
    [ -z "$(herdr_calls)" ]
}

@test "open PR with -y: renames anyway" {
    git push --quiet -u origin topic
    STUB_GH_PR=$'12\tOPEN\thttps://example.invalid/pull/12' run wkt rename -y -b better </dev/null
    [ "$status" -eq 0 ]
    git -C "$ORIGIN" show-ref --verify --quiet refs/heads/better
    [ -d "$LAYOUT/better" ]
}

@test "merged PR doesn't prompt" {
    git push --quiet -u origin topic
    STUB_GH_PR=$'12\tMERGED\thttps://example.invalid/pull/12' run wkt rename -b better </dev/null
    [ "$status" -eq 0 ]
    lacks "$output" "PR #12"
    [ -d "$LAYOUT/better" ]
}

@test "branch names with slashes swap the whole branch path" {
    cd "$LAYOUT/main"
    wkt new -b feat/login >/dev/null 2>&1
    cd "$LAYOUT/feat/login"
    run wkt rename -b fix/auth/login
    [ "$status" -eq 0 ]
    [ "$(git -C "$LAYOUT/fix/auth/login" branch --show-current)" = fix/auth/login ]
    [ ! -e "$LAYOUT/feat" ]
}

@test "normal repo: rename stays under the worktree root" {
    make_clone
    cd "$CLONE"
    wkt new -b topic >/dev/null 2>&1
    cd "$HOME/.herdr/worktrees/acme/widget/topic"
    run wkt rename -b better
    [ "$status" -eq 0 ]
    [ -d "$HOME/.herdr/worktrees/acme/widget/better" ]
    contains "$output" "  ~/.herdr/worktrees/acme/widget/better  "
}

@test "refuses the main checkout" {
    make_clone
    cd "$CLONE"
    run wkt rename -b better
    [ "$status" -eq 1 ]
    contains "$output" "Refusing to rename the main checkout."
    contains "$output" "created by 'wkt new'"
}

@test "refuses a detached HEAD" {
    git checkout --quiet --detach
    run wkt rename -b better
    [ "$status" -eq 1 ]
    contains "$output" "Detached HEAD"
}

@test "refuses the same name" {
    run wkt rename -b topic
    [ "$status" -eq 1 ]
    contains "$output" "already the current branch name"
}

@test "refuses an existing branch" {
    run wkt rename -b develop
    [ "$status" -eq 1 ]
    contains "$output" "Branch 'develop' already exists."
    [ -d "$LAYOUT/topic" ]
}

@test "refuses an invalid name" {
    run wkt rename -b "bad..name"
    [ "$status" -eq 1 ]
    contains "$output" "not a valid branch name"
}

@test "refuses when the target directory exists" {
    mkdir "$LAYOUT/better"
    run wkt rename -b better
    [ "$status" -eq 1 ]
    contains "$output" "already exists"
    [ "$(git -C "$LAYOUT/topic" branch --show-current)" = topic ]
}

@test "without herdr: renames, warns, exits 0" {
    rm "$STUB_BIN/herdr"
    run --separate-stderr wkt rename -b better
    [ "$status" -eq 0 ]
    [ -d "$LAYOUT/better" ]
    contains "$stderr" "herdr not found on PATH"
    lacks "$output" "Herdr workspace updated"
}

@test "when herdr fails: renames, warns, exits 0" {
    STUB_HERDR_FAIL=1 run --separate-stderr wkt rename -b better
    [ "$status" -eq 0 ]
    [ -d "$LAYOUT/better" ]
    contains "$stderr" "Herdr didn't open the worktree"
}
