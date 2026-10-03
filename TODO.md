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

Background:

- **Host (personal profile):** neotest and nvim-dap work for
  `dev-container-tests/cmake-catch2` (CMake, Catch2 v3). codelldb comes from
  nix (`home/modules/nvim.nix`); mason is gone.
- **`config/nvim/local-plugins/neotest-testmate/`:** a local lazy.nvim plugin,
  loaded through `dir = …` in `config/nvim/lua/plugins/dap.lua`, with
  neotest-ctest as its dependency. It is a neotest adapter that runs C++ test
  executables directly, the way VSCode's C++ TestMate does, instead of
  through CTest:
    - test cases in the source come from neotest-ctest's tree-sitter queries;
    - the executable is the newest one named `*test*` under the project's
      `build`/`out` directories (TestMate's defaults) that contains the
      source file's path, which the test macros embed through `__FILE__`
      (searched with `rg`);
    - it runs `<exe> "name1,name2" --reporter xml --out <tmp>` and turns the
      XML into results, diagnostics and an output-panel summary; debugging
      launches the same command under codelldb;
    - Catch2 v2 and v3 only, no GTest yet. No hard-coded paths.
- **`dev-container-tests/colcon-catch2/`:** test bed that mirrors the work
  setup. Two colcon packages with Catch2 v2.13.10 (FetchContent), one
  `<pkg>_test` executable per package, registered with CTest as a single
  test. Has a `.devcontainer/` (Ubuntu 24.04 with build tools, clangd, colcon,
  python3-colcon-cmake, python3-colcon-recursive-crawl).
    - Start: `bin/nix-devcontainer.sh dev-container-tests/colcon-catch2`
    - Inside: `colcon build --cmake-args -DCMAKE_BUILD_TYPE=Debug`
- **Work setup** (facts only; keep project details out of this repo): colcon
  build base `build/unittest/build`; test executable
  `build/unittest/build/<pkg>/<pkg>_test`; CTest knows one test per package
  (plain `add_test`); mostly Catch2 v2, some GTest; VSCode TestMate uses
  `envFile: /tmp/ros.env`; clangd uses
  `--compile-commands-dir=build/unittest/build`.

Steps:

1. **Verify in the colcon container.** The rustaceanvim error is fixed
   (commit 8b0fc12). Check `<leader>ts`, `tf`, `tt`, `tp` and `td` in both
   packages.
2. **Check at work (read-only)** that the executable lookup works there. From
   the project root, this should print the executable:
   `rg --files-with-matches --text --fixed-strings "$PWD/<path to a test .cpp>" build/unittest/build/<pkg>/<pkg>_test`
   If it doesn't, the build rewrites `__FILE__` (`-ffile-prefix-map`). Also
   check that test files include `<catch2/catch.hpp>`.
3. **Project-specific settings, without paths in the dotfiles:** the env file
   for test runs (neotest spec `env` and codelldb launch `env`) and clangd's
   compile-commands directory. Open decision: a project-local `.nvim.lua`
   (nvim's `exrc`, with trust prompt) or reading `.vscode/settings.json`
   directly (TestMate `envFile`, `clangd.arguments`). Add a sample test that
   only passes with a variable from the env file.
4. **GTest/GMock in neotest-testmate:** `--gtest_filter=Suite.Name:…`,
   `--gtest_output=xml:<file>`, parse GTest's XML. neotest-ctest has GTest
   queries. Add a GTest package to the sample workspace.

## Next

### 2026-10-03 · Treesitter: error in nvim, `dif` broken

Text objects stopped working: `dif` (delete inside function) does nothing
in Lua; other languages not checked yet. Both nvim-treesitter and
nvim-treesitter-textobjects are pinned to their archived `master` branches,
so this likely shares a cause with the error below. Moving to `main` means
moving textobjects to its `main` branch too, whose keymaps are set by hand
instead of through `nvim-treesitter.configs`.

`vim/treesitter.lua:197: attempt to call method 'range' (a nil value)`: once
from blink.cmp, and from the highlighter when opening `.sh` files and
Lua files (`config/nvim/lua/plugins/nvim-surround.lua`), in nvim 0.12.4.
Not reproduced headless. Lead: the bash `injections.scm` comes from
nvim-treesitter's `master` branch (archived, not meant for nvim 0.12), whose
custom directives can pass a list of nodes where 0.12 expects one. Options:
move to nvim-treesitter's `main` branch, or stop loading its queries (the
parsers already come from nix through `$NVIM_NIX_RUNTIME`). The container
briefly wrote `"branch": "main"` into `lazy-lock.json`; keep the lock
consistent.

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

### 2026-10-03 · Copilot CLI in the container

Needed for work; Claude Code covers it for now. Open question: deliver the
token through `nixfiles-secrets` (sops) so a container rebuild costs
nothing. Likely shape: a token on the host from sops, passed in by
`bin/nix-devcontainer.sh` as an environment variable or bind-mounted file,
the same mechanism as the per-workspace bash history (Later).

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

## Later

### 2026-10-03 · Register each test case with CTest (for the team)

`catch_discover_tests` / `gtest_discover_tests` gives per-test results in
ctest/colcon/CI, crash isolation, `--rerun-failed` and `-j`. Catch2 v2 can
only discover at build time, so the executable must start during
`colcon build`.

### 2026-10-03 · fzf bash completion after any command

`**<Tab>` only triggers for commands it knows, e.g. not after
`tmux source-file`. Goal: path completion after any command, and bash
completion for tmux.

### 2026-10-03 · Container bash history across rebuilds

Move `HISTFILE` to `${XDG_STATE_HOME:-$HOME/.local/state}/bash/history`
(create the directory, and move the host's `~/.bash_history` there once), and
let `bin/nix-devcontainer.sh` bind-mount
`~/.local/state/nix-devcontainer/<workspace>/bash` onto the container's
`~/.local/state/bash`. Histories stay separate: the host, and one per
workspace. Consider `PROMPT_COMMAND+=('history -a')` so commands are saved
immediately.

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

## Stale
