# TODO

- **Inbox:** new thoughts, one bullet each, unsorted. Capture now, sort later.
- **Now:** what I'm working on. One item, two at most.
- **Next:** sorted, top first.
- **Later:** worth keeping, not soon.
- **Stale:** untouched for more than a month, waiting for my review.

Every item carries the date it last changed: in its heading, or at the start of
an Inbox bullet. Bump the date when an item changes. An item older than a month
moves to Stale with its date unchanged. When I review it, it goes back to
another section with today's date, or gets deleted.

Delete an item when it's done; git history keeps it.

## Inbox

- 2026-10-04 · Code-aware spell checker in nvim. Baseline without installs:
  `:set spell`, which with treesitter only checks comments and strings.
  Candidates, all in nixpkgs with an nvim-lspconfig config: codebook
  (tree-sitter based, splits identifiers like `camelCase`), typos-lsp (list of
  known misspellings, few false positives), harper (spelling and grammar in
  comments and Markdown). ltex-ls-plus (LanguageTool) is heavier, on a JRE.

## Now

### 2026-10-03 · neotest in a container with colcon/ROS 2

neotest and nvim-dap for the work setup, through
`config/nvim/local-plugins/neotest-testmate/`: an adapter that runs test
executables directly, like VSCode's C++ TestMate, instead of through CTest. Test
bed: `dev-container-tests/colcon-catch2/`. Keep work project details out of this
repo; facts only.

1. **Verify in the colcon container.** Start it with
   `bin/nix-devcontainer.sh dev-container-tests/colcon-catch2`, build inside
   with `colcon build --cmake-args -DCMAKE_BUILD_TYPE=Debug`, then check
   `<leader>ts`, `tf`, `tt`, `tp` and `td` in both packages. For comparison,
   all of these work on the host with `dev-container-tests/cmake-catch2`.
2. **Check at work (read-only)** that the executable lookup works there. The
   adapter picks the newest `*test*` executable under `build`/`out` that
   contains the test source's path, which the test macros embed through
   `__FILE__`. At work the executable is
   `build/unittest/build/<pkg>/<pkg>_test`. From the project root, this should
   print it:
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

## Later

### 2026-10-03 · fzf bash completion after any command

`**<Tab>` only triggers for commands it knows, e.g. not after
`tmux source-file`. Goal: path completion after any command, and bash completion
for tmux.

### 2026-10-03 · `<leader>ba` fails on terminal buffers

Overseer related; overseer is disabled for now (`enabled = false` in
`config/nvim/lua/plugins/task.lua`). The error went away after an nvim restart,
so whether overseer opened the terminal is still open. Cause not found:
overseer's own task buffers are unlisted scratch buffers from `nvim_open_term`,
while the `term://…:/usr/bin/sh` name is what `:terminal` with shell
`/usr/bin/sh` produces. `%bd` stops at the first buffer `:bdelete` refuses (E89:
a terminal with a running job, or a modified buffer), so the current buffer
stays open too; `<leader>bo` (`%bd | e# | bd#`) breaks the same way. Fix drafted
(not applied): a `delete_buffers(keep)` helper in `config/nvim/lua/keymaps.lua`
that runs `pcall(vim.cmd.bdelete, buf)` on each listed buffer, current one last,
and lists what it kept. Recommended: skip refused buffers rather than
force-delete.

### 2026-10-03 · nvim statusline at the top

The empty line under the statusline is the command line (`cmdheight`). Option:
vim-tpipeline, which moves nvim's statusline into the tmux status, which already
sits at the top (`status-position top`). Alternative without tmux: lualine as
`tabline`/`winbar`, `laststatus=0`, `cmdheight=0`.

### 2026-10-04 · nvim plugins to evaluate

- nvim-hlslens: match index next to search results.
- blink-ripgrep.nvim: blink.cmp source with words from the whole project.
- treesj: split/join on treesitter nodes; overlaps mini.splitjoin.
- tiny-inline-diagnostic.nvim: nicer inline diagnostics.
- quicker.nvim: editable, nicer quickfix list.
- nvim-chainsaw: insert and remove log statements.

### 2026-10-03 · Copilot CLI in the container

Needed for work; Claude Code covers it for now. Open question: deliver the token
through `nixfiles-secrets` (sops) so a container rebuild costs nothing. Likely
shape: a token on the host from sops, passed in by `bin/nix-devcontainer.sh` as
an environment variable or bind-mounted file, like the per-workspace bash
history mount there.

### 2026-10-03 · nvim plugins through nix

Install plugins from nixpkgs-unstable instead of lazy.nvim's git clones; maybe
some config too, but keep the config in Lua files, not Lua in nix strings.
nixpkgs' nvim-treesitter already follows `main`.

### 2026-10-03 · tmux plugins and config through nix

Replace tpm (`~/.tmux/plugins`) with nix-installed plugins; the config is small
enough to move into nix as well.

### 2026-10-03 · Window manager: noctalia

Look into noctalia when picking a window manager (the Super layer); maybe after
moving to NixOS, maybe not.

### 2026-10-03 · TUIs to look into

- TUIOS: window manager inside the terminal.
- superfile: file manager; compare with yazi, which is in use now.

### 2026-10-03 · Register each test case with CTest (for the team)

`catch_discover_tests` / `gtest_discover_tests` gives per-test results in
ctest/colcon/CI, crash isolation, `--rerun-failed` and `-j`. At work, CTest now
knows one test per package (plain `add_test`). Catch2 v2 can only discover at
build time, so the executable must start during `colcon build`.

## Stale
