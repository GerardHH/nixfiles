# TODO

- **Inbox:** new thoughts, one line each, unsorted. Capture now, sort later.
- **Now:** what I'm working on. One item, two at most.
- **Next:** sorted, top first.
- **Later:** worth keeping, not soon.
- **Stale:** untouched for more than a month, waiting for my review.

Every item carries the date it last changed: in its heading, or at the
start of an Inbox line. Bump the date when an item changes. An item older than
a month moves to Stale with its date unchanged. When I review it, it goes back
to another section with today's date, or gets deleted.

Delete an item when it's done; git history keeps it.

## Inbox

## Now

### 2026-10-03 · neotest in a container with colcon/ROS 2

neotest and nvim-dap for the work setup, through
`config/nvim/local-plugins/neotest-testmate/`: an adapter that runs test
executables directly, like VSCode's C++ TestMate, instead of through CTest.
Test bed: `dev-container-tests/colcon-catch2/`. Keep work project details
out of this repo; facts only.

1. **Verify in the colcon container.** Start it with
   `bin/nix-devcontainer.sh dev-container-tests/colcon-catch2`, build inside
   with `colcon build --cmake-args -DCMAKE_BUILD_TYPE=Debug`, then check
   `<leader>ts`, `tf`, `tt`, `tp` and `td` in both packages. For comparison,
   all of these work on the host with `dev-container-tests/cmake-catch2`.
2. **Check at work (read-only)** that the executable lookup works there. The
   adapter picks the newest `*test*` executable under `build`/`out` that
   contains the test source's path, which the test macros embed through
   `__FILE__`. At work the executable is
   `build/unittest/build/<pkg>/<pkg>_test`. From the project root, this
   should print it:
   `rg --files-with-matches --text --fixed-strings "$PWD/<path to a test .cpp>" build/unittest/build/<pkg>/<pkg>_test`
   If it doesn't, the build rewrites `__FILE__` (`-ffile-prefix-map`). Also
   check that test files include `<catch2/catch.hpp>` (Catch2 v2).
3. **Project-specific settings, without paths in the dotfiles:** the env file
   for test runs (neotest spec `env` and codelldb launch `env`) and clangd's
   compile-commands directory. At work, TestMate uses
   `envFile: /tmp/ros.env` and clangd uses
   `--compile-commands-dir=build/unittest/build`. Open decision: a
   project-local `.nvim.lua` (nvim's `exrc`, with trust prompt) or reading
   `.vscode/settings.json` directly (TestMate `envFile`, `clangd.arguments`).
   Add a sample test to the test bed that only passes with a variable from
   the env file.
4. **GTest/GMock in neotest-testmate:** some work packages use GTest; the
   adapter handles only Catch2 v2 and v3. Catch2 runs as
   `<exe> "name1,name2" --reporter xml --out <tmp>`; for GTest that becomes
   `--gtest_filter=Suite.Name:…` and `--gtest_output=xml:<file>`, plus
   parsing GTest's XML. neotest-ctest has GTest queries. Add a GTest package
   to the test bed.

## Next

### 2026-10-03 · Claude Code: vi keybindings

Try `/vim` in the prompt; if it sticks, set `editorMode` in
`config/claude/settings.json`.

### 2026-10-03 · `<leader>ba` fails on terminal buffers

Close all buffers reports
`E89: term://…:/usr/bin/sh will be killed (add ! to override)`: a terminal
buffer (an overseer task?) refuses a non-forced delete. Decide whether to
skip terminal buffers or force-delete them.

### 2026-10-03 · Key layers: finish up

Ctrl for the program (nvim, fzf), Alt for tmux, Super for a future window
manager. Committed in ccfe283. Left: check for remaining Alt conflicts (nvim,
bash, alacritty). If not done yet, clean up the running tmux:
`for key in C-h C-j C-k C-l 'C-\'; do tmux unbind-key -n "$key"; done`,
`tmux source-file ~/.config/tmux/tmux.conf`,
`rm --recursive --force ~/.tmux/plugins/vim-tmux-navigator`, and `:Lazy clean`
in nvim.

### 2026-10-03 · Claude Code: `@` completion no longer pre-selects

After an update, `@` file completion no longer pre-selects the first match.
Find out whether a setting restores it, or report it with `/feedback`.

### 2026-10-03 · Container bash history across rebuilds

Move `HISTFILE` to `${XDG_STATE_HOME:-$HOME/.local/state}/bash/history`
(create the directory, and move the host's `~/.bash_history` there once), and
let `bin/nix-devcontainer.sh` bind-mount
`~/.local/state/nix-devcontainer/<workspace>/bash` onto the container's
`~/.local/state/bash`. Histories stay separate: the host, and one per
workspace. Consider `PROMPT_COMMAND+=('history -a')` so commands are saved
immediately.

### 2026-10-03 · fzf bash completion after any command

`**<Tab>` only triggers for commands it knows, e.g. not after
`tmux source-file`. Goal: path completion after any command, and bash
completion for tmux.

## Later

### 2026-10-03 · nvim statusline at the top

The empty line under the statusline is the command line (`cmdheight`).
Option: vim-tpipeline, which moves nvim's statusline into the tmux status,
which already sits at the top (`status-position top`). Alternative without
tmux: lualine as `tabline`/`winbar`, `laststatus=0`, `cmdheight=0`.

### 2026-10-03 · nvim plugins to evaluate

- nvim-hlslens: match index next to search results.
- SchemaStore.nvim: JSON/YAML schemas for the language servers.
- blink-ripgrep.nvim: blink.cmp source with words from the whole project.
- treesj: split/join on treesitter nodes; overlaps mini.splitjoin.
- tiny-inline-diagnostic.nvim: nicer inline diagnostics.
- quicker.nvim: editable, nicer quickfix list.
- nvim-chainsaw: insert and remove log statements.

### 2026-10-03 · Copilot CLI in the container

Needed for work; Claude Code covers it for now. Open question: deliver the
token through `nixfiles-secrets` (sops) so a container rebuild costs
nothing. Likely shape: a token on the host from sops, passed in by
`bin/nix-devcontainer.sh` as an environment variable or bind-mounted file,
the same mechanism as the "Container bash history" item.

### 2026-10-03 · nvim plugins through nix

Install plugins from nixpkgs-unstable instead of lazy.nvim's git clones; maybe
some config too, but keep the config in Lua files, not Lua in nix strings.
nixpkgs' nvim-treesitter already follows `main`.

### 2026-10-03 · tmux plugins and config through nix

Replace tpm (`~/.tmux/plugins`) with nix-installed plugins; the config is
small enough to move into nix as well.

### 2026-10-03 · Window manager: noctalia

Look into noctalia when picking a window manager (the Super layer); maybe
after moving to NixOS, maybe not.

### 2026-10-03 · TUIs to look into

- TUIOS: window manager inside the terminal.
- superfile: file manager; compare with yazi, which is in use now.

### 2026-10-03 · Register each test case with CTest (for the team)

`catch_discover_tests` / `gtest_discover_tests` gives per-test results in
ctest/colcon/CI, crash isolation, `--rerun-failed` and `-j`. At work, CTest
now knows one test per package (plain `add_test`). Catch2 v2 can
only discover at build time, so the executable must start during
`colcon build`.

## Stale
