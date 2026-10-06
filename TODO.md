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

- 2026-10-05 · Opening a file with merge conflicts errors in nvim:
  `git-conflict.lua:655: attempt to call field 'disable' (a nil value)`, from
  the `GitConflictDetected` autocmd. git-conflict.nvim (a1badcd) still calls
  `vim.diagnostic.disable(bufnr)`, which nvim 0.12 removed; our
  `disable_diagnostics = true` in `config/nvim/lua/plugins/git.lua` triggers
  it. Resolving a conflict (`<leader>gct`, then saving) fails too, at
  `git-conflict.lua:665` in `GitConflictResolved`: `enable: expected boolean,
  got number`, as it calls the old `vim.diagnostic.enable(bufnr)`. It fires
  once from `choose` and again from the later re-parse (`process`, line 673).
  Goal beyond the error: hide errors and warnings while a buffer has conflict
  markers, as they clutter the conflict and make it harder to read; the
  markers alone already break the parse, so the diagnostics are mostly noise.
  Fix: set `disable_diagnostics = false` and do it ourselves from those two
  autocmds with `vim.diagnostic.enable(false, { bufnr = … })` and
  `vim.diagnostic.enable(true, { bufnr = … })`, or find a maintained fork.
  Check that diagnostics come back after the last conflict is resolved.
- 2026-10-06 · nixd completion and hover docs for our own options, such as
  `languages.<name>.packages` from `home/modules/languages/default.nix`.
  Likely set up already: `config/nvim/lua/plugins/lsp.lua` points nixd's
  `options.home-manager` at `homeConfigurations.<personal|container>.options`
  of `~/nixfiles`, which holds our options next to home-manager's. Check
  whether it works in e.g. `home/modules/languages/nix.nix`, and whether the
  `attrsOf submodule` under `languages` gets completion. If not, see
  `:LspLog`, and whether files outside the configuration's entry point need
  their own options expression.

## Now

### 2026-10-04 · neotest in a container with colcon/ROS 2

neotest and nvim-dap for the work setup, through
`config/nvim/local-plugins/neotest-testmate/`: an adapter that runs test
executables directly, like VSCode's C++ TestMate, instead of through CTest.
Supports Catch2 v2/v3 and, since 19dd9fd, GTest/GMock (`catch2.lua`,
`gtest.lua`, `xml.lua`; framework picked by `#include`). Test bed:
`dev-container-tests/colcon-catch2/`, with GTest in `src/toolbox/greeter`. Keep
work project details out of this repo; facts only.

1. **Catch2 regression since 19dd9fd:** Catch2 tests run forever, in the
   container test bed and at work; GTest tests in the test bed work, and
   `u` (stop) in the summary does nothing. 810e894 is the last good adapter.
   A headless neotest run (`neotest.setup` + `neotest.run.run(file)`, cwd in
   `dev-container-tests/cmake-catch2`, scratch scripts in
   `/tmp/claude-1000/*.lua` until reboot) on the host never finished
   discovery: the log stops after "started". Calling the adapter's functions
   directly did work, Catch2 included. Next: run that harness against
   810e894 to tell a harness problem from the regression. Suspect: the new
   `detect()` in `init.lua` (`pcall(lib.files.read)` plus an `#include`
   scan, run in `discover_positions` and `build_spec`), which replaced
   neotest-ctest's tree-sitter detection.
2. **Catch2 with GMock:** `detect()` returns the framework of the first
   matching `#include`, so a Catch2 file that includes `gmock/gmock.h` before
   `catch2/catch.hpp` is taken for GTest. It worked at work only because the
   old adapter knew Catch2 alone. Fix: Catch2 wins whenever one of its
   headers is included. Add a Catch2 test file that uses GMock to the test
   bed.
3. **Stay in the debugger when a test fails,** as TestMate does
   (`testMate.cpp.debug.breakOnFailure`, on by default). Under the dap
   strategy, add `--break` for Catch2 and `--gtest_break_on_failure` for
   GTest; both trap at the failing assertion, so codelldb stops there with
   the stack. Check that the report still gets written, or that the
   interrupted run keeps the previous results (as `results` does now).
4. **Rename the test bed** to `dev-container-tests/colcon-neotest-testmate`
   (`git mv`), as it targets the adapter, not Catch2. Also update `name` in
   its `.devcontainer/devcontainer.json` (`nixfiles-colcon-catch2`). The
   per-workspace bash history from `bin/nix-devcontainer.sh` is keyed on the
   path, so it starts empty.
5. **Verify GTest at work** on a GTest package, including `td`. A `TEST_P`
   or `TYPED_TEST` is one neotest test; its instances add up in the results.
   Not supported: `TYPED_TEST_P`.
6. **Publish neotest-testmate as a plugin?** After it has proven itself at work.
   Open: own repo, vendoring neotest-ctest's Catch2 query (its only remaining
   use), README, tests (the headless harness could become one, with CI building
   small Catch2 and GTest samples), and the name ("TestMate" is someone else's
   VSCode extension). Also test the claim Catch2 v2/v3 is supported.

## Next

### 2026-10-04 · Make remove existing container optional

`bin/nix-devcontainer.sh`: make `--remove-existing-container` an option
(default: keep the container). Removing it every time throws away lazy.nvim's
plugin clones and the nvim sessions; plugins through nix (Later) only fixes the
first. The usage comment promises forwarding extra `devcontainer up` arguments,
but the script doesn't pass `$@` on. Perhaps also introduce some autocompletion
for commands?

### 2026-10-04 · tmux inside the container while the container shell already

Runs in a host tmux pane: nested tmux (prefix clash, two status lines).

### 2026-10-04 · setlocale warnings in the work container

bash warns it cannot set `en_US.UTF-8` (LC_CTYPE, LC_COLLATE). Our config sets
no `LANG`; the image's glibc has no such locale, and `LOCALE_ARCHIVE_2_27` only
helps nix programs. Find where `LANG` comes from (image `ENV`, devcontainer.json
`containerEnv`/`remoteEnv`), then e.g. `--remote-env LANG=C.UTF-8` in
`bin/nix-devcontainer.sh`.

### 2026-10-04 · Wierd drawing in gutter

Container only: opening a `.cpp` file (test or not) the first time puts `TEST`
in the sign column; line numbers overwrite it only partly, and closing and
reopening the buffer brings it back. Next time, find the owner with
`:lua =vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, { details = true, type = "sign" })`.
Suspect: todo-comments, whose highlight pattern `.*<(KEYWORDS)\s*` needs no `:`
and so matches `TEST` in `TEST_CASE`, before treesitter can tell it isn't a
comment. The leftover remnants hint at a glyph that nvim and the terminal draw
at different widths (the container forces `TERM=xterm-256color`).

### 2026-10-03 · nvim plugins through nix

Install plugins from nixpkgs-unstable instead of lazy.nvim's git clones; maybe
some config too, but keep the config in Lua files, not Lua in nix strings.
nixpkgs' nvim-treesitter already follows `main`.

### 2026-10-03 · tmux plugins and config through nix

Replace tpm (`~/.tmux/plugins`) with nix-installed plugins; the config is small
enough to move into nix as well.

## Later

### 2026-10-03 · Copilot CLI in the container

Needed for work; Claude Code covers it for now. Open question: deliver the token
through `nixfiles-secrets` (sops) so a container rebuild costs nothing. Likely
shape: a token on the host from sops, passed in by `bin/nix-devcontainer.sh` as
an environment variable or bind-mounted file, like the per-workspace bash
history mount there.

### 2026-10-04 · Pasting host → container only works with Ctrl+Shift+V

(the terminal's own paste), not with nvim's `p` or the middle mouse button. By
design for now: without wl-copy/xclip, `config/nvim/lua/options/clipboard.lua`
copies through OSC 52 but serves `+`/`*` pastes from register 0, because
terminals refuse OSC 52 reads. With `mouse` on, a middle click goes to nvim,
which pastes `*`; Shift+middle click is the terminal's own primary paste.
Options: bind-mount the Wayland socket and add wl-clipboard in the container, or
let tmux answer OSC 52 reads.

### 2026-10-03 · fzf bash completion after any command

`**<Tab>` only triggers for commands it knows, e.g. not after
`tmux source-file`. Goal: path completion after any command, and bash completion
for tmux.

### 2026-10-04 · `install.sh` ends with "Done

Open a new shell, then rebuild with: 'nix-switch.sh'", which reads as two
required steps. No rebuild is needed: `hm_switch` already activated the profile;
`nix-switch.sh` is for later changes. In the container,
`bin/nix-devcontainer.sh` already drops into a new shell after `install.sh`.
Reword it, or leave it out there.

### 2026-10-04 · nvim plugins to evaluate

- nvim-hlslens: match index next to search results.
- blink-ripgrep.nvim: blink.cmp source with words from the whole project.
- treesj: split/join on treesitter nodes; overlaps mini.splitjoin.
- tiny-inline-diagnostic.nvim: nicer inline diagnostics.
- quicker.nvim: editable, nicer quickfix list.
- nvim-chainsaw: insert and remove log statements.

### 2026-10-04 · Code-aware spell checker in nvim

Baseline without installs: `:set spell`, which with treesitter only checks
comments and strings. Candidates, all in nixpkgs with an nvim-lspconfig config:
codebook (tree-sitter based, splits identifiers like `camelCase`), typos-lsp
(list of known misspellings, few false positives), harper (spelling and grammar
in comments and Markdown). ltex-ls-plus (LanguageTool) is heavier, on a JRE.

### 2026-10-03 · TUIs to look into

- TUIOS: window manager inside the terminal.
- superfile: file manager; compare with yazi, which is in use now.

### 2026-10-03 · nvim statusline at the top

The empty line under the statusline is the command line (`cmdheight`). Option:
vim-tpipeline, which moves nvim's statusline into the tmux status, which already
sits at the top (`status-position top`). Alternative without tmux: lualine as
`tabline`/`winbar`, `laststatus=0`, `cmdheight=0`.

### 2026-10-03 · Window manager: noctalia

Look into noctalia when picking a window manager (the Super layer); maybe after
moving to NixOS, maybe not.

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

### 2026-10-03 · Register each test case with CTest (for the team)

`catch_discover_tests` / `gtest_discover_tests` gives per-test results in
ctest/colcon/CI, crash isolation, `--rerun-failed` and `-j`. At work, CTest now
knows one test per package (plain `add_test`). Catch2 v2 can only discover at
build time, so the executable must start during `colcon build`.

## Stale
