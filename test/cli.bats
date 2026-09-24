#!/usr/bin/env bats

load test_helper

setup() { common_setup; }

@test "--version prints the canonical name under either name" {
    run herdr-wkt --version
    [ "$status" -eq 0 ]
    [ "$output" = "herdr-wkt 1.0.0" ]

    run wkt -V
    [ "$status" -eq 0 ]
    [ "$output" = "herdr-wkt 1.0.0" ]
}

@test "--help names the command it was run as" {
    run herdr-wkt --help
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "Usage: herdr-wkt <command> [options]" ]
    contains "$output" "HERDR_WKT_ROOT"

    run wkt -h
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "Usage: wkt <command> [options]" ]
    lacks "$output" "herdr-wkt <command>"

    run wkt help
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "Usage: wkt <command> [options]" ]
}

@test "command help exits 0 and uses the alias name" {
    for cmd in setup new rename; do
        run wkt "$cmd" --help
        [ "$status" -eq 0 ]
        starts_with "${lines[0]}" "Usage: wkt $cmd"
    done
    run wkt new -h
    [ "$status" -eq 0 ]
    starts_with "${lines[0]}" "Usage: wkt new"
}

@test "errors point at help under the alias name" {
    run wkt new
    [ "$status" -eq 2 ]
    contains "$output" "Branch name (-b) is required."
    contains "$output" "Run 'wkt new --help' for usage."

    run herdr-wkt bogus
    [ "$status" -eq 2 ]
    contains "$output" "Unknown command: bogus"
    contains "$output" "Run 'herdr-wkt --help' for usage."
}

@test "no arguments prints usage to stderr and exits 2" {
    run --separate-stderr wkt
    [ "$status" -eq 2 ]
    [ -z "$output" ]
    starts_with "$stderr" "Usage: wkt"
}

@test "unknown top-level option" {
    run wkt --frobnicate
    [ "$status" -eq 2 ]
    contains "$output" "Unknown option: --frobnicate"
}

@test "new: argument errors" {
    run wkt new -x
    [ "$status" -eq 2 ]
    contains "$output" "Unknown option: -x"

    run wkt new -b
    [ "$status" -eq 2 ]
    contains "$output" "Option -b needs a value."

    run wkt new -b topic extra
    [ "$status" -eq 2 ]
    contains "$output" "Unexpected argument: extra"

    run wkt new -s main
    [ "$status" -eq 2 ]
    contains "$output" "Branch name (-b) is required."
}

@test "rename: argument errors" {
    run wkt rename
    [ "$status" -eq 2 ]
    contains "$output" "New branch name (-b) is required."

    run wkt rename -q
    [ "$status" -eq 2 ]
    contains "$output" "Unknown option: -q"

    run wkt rename -b a b
    [ "$status" -eq 2 ]
    contains "$output" "Unexpected argument: b"
}

@test "setup: argument errors" {
    run wkt setup
    [ "$status" -eq 2 ]
    contains "$output" "Repo URL is required."

    run wkt setup a b
    [ "$status" -eq 2 ]
    contains "$output" "Unexpected argument: b"

    run wkt setup -x
    [ "$status" -eq 2 ]
    contains "$output" "Unknown option: -x"
}

@test "new outside a repository" {
    mkdir empty && cd empty
    run wkt new -b topic
    [ "$status" -eq 1 ]
    contains "$output" "Not inside a Git repository."
}

@test "rename outside a repository" {
    mkdir empty && cd empty
    run wkt rename -b topic
    [ "$status" -eq 1 ]
    contains "$output" "Not inside a Git worktree."
}

@test "output has no colour when not a terminal" {
    run wkt new
    lacks "$output" $'\e['
}

@test "the script parses" {
    run zsh -n "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "the assertion helpers fail when they should" {
    run contains "abc" "x"
    [ "$status" -ne 0 ]
    run lacks "abc" "b"
    [ "$status" -ne 0 ]
    run starts_with "abc" "b"
    [ "$status" -ne 0 ]
}
