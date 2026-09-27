# wkt

[![CI](https://github.com/wmxscott/wkt/actions/workflows/ci.yml/badge.svg)](https://github.com/wmxscott/wkt/actions/workflows/ci.yml)

Git worktrees in a predictable place, one command each. Inside [Herdr](https://herdr.dev), they open as Herdr workspaces and stay in sync with them when you rename a branch.

Give each piece of work its own git worktree and parallel tasks, or coding agents, can't trip over each other's checkouts. wkt makes that one command: it puts the worktree in a predictable place and starts the branch from a freshly fetched default branch. When the branch earns a better name, one more command renames the branch, its directory and the branch on origin together.

Herdr runs coding agents in persistent terminal workspaces. When you run wkt inside Herdr, it also opens each new worktree as a Herdr workspace, and a rename moves the workspace with it. Pass `--no-herdr` to skip that for one command.

```console
$ wkt new -b fix-login
→ updating main from origin
→ branching from origin/main
✓ fix-login  ~/.herdr/worktrees/acme/widget/fix-login  opened in Herdr
```

wkt was called herdr-wkt before 2.0.

## Why not `herdr worktree create`?

Herdr can create worktrees itself, and wkt uses Herdr's `worktree open` to show them. The difference is what happens around the checkout:

- **Remote branches.** A branch that only exists on origin is checked out tracking it. Herdr creates a new branch of that name from `--base` or `HEAD` instead.
- **Fresh starting point.** A new branch starts from the default branch, or `-s <source>`, after fetching it from origin, so it isn't based on a stale local copy.
- **Reopening.** Asking again for a branch that already has a worktree, wherever it is, opens that worktree.
- **Renaming.** Herdr has no rename for worktrees. `wkt rename` renames the branch locally and on origin, moves the directory and points the Herdr workspace at the new path.
- **`.bare` layouts.** `wkt setup` clones a repository into a layout where every branch is a sibling folder, and `wkt new` keeps to it.

## Install

### Homebrew

```sh
brew install wmxscott/tap/wkt
```

### From source

Needs zsh and git, which macOS already has.

```sh
git clone https://github.com/wmxscott/wkt.git
install -d ~/.local/bin
install wkt/bin/wkt ~/.local/bin/
```

Herdr is optional. wkt only talks to it when run inside a Herdr pane, which it detects from `HERDR_TAB_ID`. There, if `herdr` isn't on your `PATH` or can't reach the server, wkt still does the git work, prints a warning with the `herdr` command to run later, and exits successfully.

## Usage

```
wkt new -b <branch> [-s <source>] [-n <label>] [--no-herdr]
wkt rename -b <new-branch> [-n <label>] [-y] [--no-herdr]
wkt setup <repo-url>
wkt --help | --version
```

Every command also takes `--help`.

### `wkt new`

Run it anywhere in a repository: the main checkout, any worktree, or the top of a `.bare` layout. It picks the first of these that applies:

1. `<branch>` is already checked out in a worktree: use that worktree.
2. The worktree folder for `<branch>` already exists: use it.
3. `<branch>` exists locally: add a worktree for it.
4. `<branch>` exists on origin: create it locally, tracking origin's.
5. Otherwise, fetch `<source>` from origin and create `<branch>` from it. The new branch doesn't track `<source>`, so the first push needs `git push -u origin HEAD`, or set `push.autoSetupRemote`.

Inside Herdr, it then opens the worktree with `herdr worktree open` and focuses it.

| Option | |
|---|---|
| `-b <branch>` | Branch to create or open. Also the worktree's folder name. Required |
| `-s <source>` | Branch to start a new branch from. Defaults to the repository's default branch: origin's `HEAD`, else `main` or `master` |
| `-n <label>` | Label for the Herdr workspace. Without it, Herdr picks one |
| `--no-herdr` | Don't open the worktree in Herdr, for when you want the worktree but not another workspace |

### `wkt rename`

Run it from inside a worktree to give its branch a new name. It:

1. Renames the branch on origin, if it was pushed. When origin is on GitHub and [`gh`](https://cli.github.com) is installed, it uses GitHub's branch-rename API. Otherwise, or if that fails, it pushes the new name and deletes the old one.
2. Renames the local branch and moves the worktree folder to match.
3. Inside Herdr, points the Herdr workspace at the new folder, labelled with the new branch name. Run it from outside Herdr, or with `--no-herdr`, and an open workspace keeps the old path until you reopen it.

Your shell stays in the old folder, which no longer exists, so `cd` to the path it prints.

If the branch has an open pull request, it stops and asks first. GitHub closes an open PR when its branch is renamed through git or the API; only the rename button in GitHub's web UI keeps it open. To keep the PR, rename the branch on GitHub, then run `wkt rename` to bring the local branch, folder and Herdr workspace in line. Without a terminal to ask on, it stops unless you pass `-y`.

| Option | |
|---|---|
| `-b <new-branch>` | New branch name. Also the new folder name. Required |
| `-n <label>` | Label for the Herdr workspace. Defaults to the new branch name |
| `-y` | Rename even when an open pull request would be closed |
| `--no-herdr` | Leave the Herdr workspace alone |

It won't rename the main checkout of a normal clone, a detached `HEAD`, or onto a branch or folder that already exists.

### `wkt setup`

Run it in a new, empty folder to clone a repository into a `.bare` layout:

```console
$ mkdir widget && cd widget
$ wkt setup git@github.com:acme/widget.git
```

```
widget/
├── .bare/     the repository, cloned with --bare
├── .git       a file containing "gitdir: ./.bare"
└── main/      a worktree for the default branch
```

It configures origin to fetch every branch and sets the default branch's worktree to track origin's. It doesn't open anything in Herdr.

## Where worktrees go

Worktrees are named after their branch. A branch with slashes, like `feat/login`, nests: `feat/login/`.

**`.bare` layouts.** When the repository's git directory is called `.bare`, worktrees go next to it, so everything for one repository stays in one folder:

```
widget/
├── .bare/
├── main/
└── fix-login/
```

**Normal clones.** Worktrees go outside the checkout, under

```
$WKT_ROOT/<org>/<repo>/<branch>
```

`<org>` and `<repo>` come from origin's URL, so `git@github.com:acme/widget.git` gives `acme/widget`. A repository without an origin uses `local/<folder name>`.

`WKT_ROOT` defaults to `~/.herdr/worktrees`, the folder Herdr's own `worktrees.directory` setting uses by default, so worktrees you make from Herdr's sidebar and from wkt end up side by side. If you've changed Herdr's setting, or don't use Herdr, set `WKT_ROOT` to wherever you want them.

## Configuration

wkt has no config file. It reads these environment variables:

| Variable | Default | |
|---|---|---|
| `WKT_ROOT` | `~/.herdr/worktrees` | Where worktrees of normal clones go. Must be absolute; a leading `~` is expanded. The pre-2.0 name, `HERDR_WKT_ROOT`, is still read when `WKT_ROOT` is unset |
| `HERDR_TAB_ID` | *(set by Herdr)* | Its presence means wkt is running inside Herdr, so it opens worktrees there |
| `NO_COLOR` | *(unset)* | Set to anything to turn off coloured output. Output is plain whenever it isn't going to a terminal |

For example, in `~/.zshenv`:

```sh
export WKT_ROOT=~/src/worktrees
```

## Exit status

| Status | |
|---|---|
| `0` | Done. This includes when Herdr couldn't be reached, which only warns |
| `2` | Bad arguments |
| Anything else | Something went wrong, such as not being in a repository or a folder in the way. A failing git command passes on its own status |

## Coding agents

An agent skill that teaches coding agents to start work with `wkt new` and rename it with `wkt rename` ships as the `herdr` plugin in [wmxscott/ai-toolkit](https://github.com/wmxscott/ai-toolkit).

## Development

```sh
brew install bats-core
bats test
zsh -n bin/wkt
```

The tests use [bats](https://github.com/bats-core/bats-core). Each one runs in a temporary folder against a local bare repository standing in for origin, with a throwaway `HOME`, every `HERDR_*` variable removed except a dummy `HERDR_TAB_ID`, and stub `herdr` and `gh` commands first on `PATH`. They never touch a running Herdr, GitHub or your own repositories. The stub `herdr` records its arguments, so the tests check exactly what wkt asks Herdr to do.

`contrib/wkt.rb` is the Homebrew formula.

## License

[MIT](LICENSE)
